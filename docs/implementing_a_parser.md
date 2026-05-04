# Implementing a request parser

Prato filters, sorts, paginates and selects data based on parameters. 
These parameters can come from any place, but in general case they come from http requests.

To allow Prato to be flexible in regards to any format of requests or parameters, it uses an object of type `Prato::Query::Parameters`.
This means that if the `params` object in `.page(scope, params)`, `.full(scope, params)` or `.batches(scope, params)` is a `Prato::Query::Parameters`,
then Prato directly uses the provided params object.
Otherwise, the provided parser in `config.parameter_parser` is used to convert `params` into a `Prato::Query::Parameters`.

The [default parser](lib/prato/query/default_parser.rb) makes some assumptions about the format of the parameters, which
is why Prato was designed taking into consideration that the user could implement their own parser.

## Contract

A parser is any object that responds to:

```ruby
parse_parameters(input, field_lookup)
```
- `input` - the value passed as `params` to those methods (often an `ActionController::Parameters` or a `Hash`).
- `field_lookup` - a callable that maps user-facing field paths to Prato's internal field names. See [The `field_lookup` argument](#field_lookup).

The result of `parse_parameters(input, field_lookup)` must be a `Prato::Query::Parameters` object.

```ruby
# filter_node: Filter | AndFilter | OrFilter
Prato::Query::Parameters.new(
  page:     Integer?,
  per_page: Integer?,
  filters:  Array[filter_node]?,
  sorts:    Array[Sort]?,
  fields:   Array[Symbol]?
)
```
- [parameters.rbs](../sig/prato/query/parameters.rbs)
- [filter.rbs](../sig/prato/query/filter.rbs)
- [and_filter.rbs](../sig/prato/query/and_filter.rbs)
- [or_filter.rbs](../sig/prato/query/or_filter.rbs)
- [sort.rbs](../sig/prato/query/sort.rbs)

| Field        | Meaning of `nil`                                 |
|--------------|--------------------------------------------------|
| `page`       | Use page `1`.                                    |
| `per_page`   | Use the configured `default_page_size`.          |
| `filters`    | No filtering is applied.                         |
| `sorts`      | No sorting is applied.                           |
| `fields`     | Every visible field is included in the output.   |

### Filter

The leaf filter:
```ruby
Prato::Query::Filter.new(field, operator, value)
```
- `field` - an internal `Symbol`, obtained from `field_lookup`.
- `operator` - a `Symbol` from the [supported operator list](../README.md#filters) (`:eq`, `:in`, `:contains`, ...).
- `value` - the filter value (scalar, or `Array` of scalars for `:in` / `:between` / ...).

Conjunction and disjunction:
```ruby
Prato::Query::AndFilter.new([filter1, filter2, ...])
Prato::Query::OrFilter.new([filter1, filter2, ...])
```
`AndFilter` and `OrFilter` may contain `Filter`s or other `AndFilter`s / `OrFilter`s, allowing arbitrary boolean trees.

### Sort
```ruby
Prato::Query::Sort.new(field, is_desc)
```
- `field` - an internal `Symbol`.
- `is_desc` - a boolean.

### Fields
An `Array` of internal `Symbol`s, each obtained from `field_lookup`.

### `field_lookup`

`field_lookup` is a callable: it responds to `.call(parts)` where `parts` is an `Array` of strings where each string represents the attribute at a nested level.
It returns the internal `Symbol` that Prato uses for that field, or `nil` if the field is not exposed by the table.

```ruby
field_lookup.call(["title"])              # => :title
field_lookup.call(["author", "name"])     # => :author___name
field_lookup.call(["unknownField"])       # => nil
```

The path parts must match the table's transformed output keys.
For a table configured with `key_transformation: :camelCase` and a column `column(author_name: [:author, :name])`,
the lookup expects `["authorName"]`, not `["author_name"]`.

A `nil` return value indicates that the requested field does not exist on the table.
If there are invalid fields, then the table's [`on_invalid_input`](../README.md#on_invalid_input) setting is used to decide what happens next.

## Subclassing `Prato::Query::DefaultParser`

The default parser separates *extraction* (reading from the input format) from *parsing* (turning extracted entries into Prato types).

The default parser offers the following hooks:

| Extraction                | Parsing                                  |
|---------------------------|------------------------------------------|
| `extract_page(input)`     | `parse_page(raw_value)`                  |
| `extract_per_page(input)` | `parse_per_page(raw_value)`              |
| `extract_filters(input)`  | `parse_filters(raw_value, field_lookup)` |
| `extract_sorts(input)`    | `parse_sorts(raw_value, field_lookup)`   |
| `extract_fields(input)`   | `parse_fields(raw_value, field_lookup)`  |

Example: In the request below, we want to update the way the values are extracted, but use the default parsing:

`{ page_info: { number, size }, where: { field => value, ... }, order_by: "-field", select: "a,b,c" }`:

```ruby
class SearchPageParser < Prato::Query::DefaultParser
  def extract_page(input)
    input.fetch(:page_info).fetch(:number)
  end

  def extract_per_page(input)
    input.fetch(:page_info).fetch(:size)
  end

  def extract_filters(input)
    input.fetch(:where).map do |field, value|
      { field: field.to_s, operator: "eq", value: value }
    end
  end

  def extract_sorts(input)
    sort = input.fetch(:order_by)
    is_desc = sort.start_with?("-")
    field = is_desc ? sort[1..-1] : sort

    [{ field: field, order: is_desc ? "desc" : "asc" }]
  end

  def extract_fields(input)
    input.fetch(:select).split(",")
  end
end
```

Configure it on a table:
```ruby
Prato.table(Book) do
  configure(parameter_parser: SearchPageParser.new)
  # ...
end
```

## Implementing a new parser

Instead of subclassing a parser, it's possible to create one from scratch:

The minimum requirements for the parser to work are:
- Have a method `parse_parameters(input, field_lookup)`
- Call `field_lookup` for every user-facing field path it encounters.
- Return a `Prato::Query::Parameters`.

For example, the following request could be parsed with the parser below:
`{ p: "3", limit: "10", match: "name:ali", order: "-age", show: "name|profile.companyName" }`:

```ruby
class MinimalParser
  def parse_parameters(input, field_lookup)
    Prato::Query::Parameters.new(
      page:     Integer(input.fetch(:p)),
      per_page: Integer(input.fetch(:limit)),
      filters:  parse_filters(input.fetch(:match), field_lookup),
      sorts:    parse_sorts(input.fetch(:order), field_lookup),
      fields:   parse_fields(input.fetch(:show), field_lookup)
    )
  end

  private

  def parse_filters(match, field_lookup)
    field, value = match.split(":", 2)
    [Prato::Query::Filter.new(resolve(field, field_lookup), :icontains, value)]
  end

  def parse_sorts(order, field_lookup)
    is_desc = order.start_with?("-")
    field = is_desc ? order[1..-1] : order
    [Prato::Query::Sort.new(resolve(field, field_lookup), is_desc)]
  end

  def parse_fields(show, field_lookup)
    show.split("|").map { |f| resolve(f, field_lookup) }
  end

  def resolve(field, field_lookup)
    field_lookup.call(field.split("."))
  end
end
```

## Validation and unknown fields

A parser does not need to validate that fields are filterable, sortable, or exposed.

After parsing, Prato validates the resulting `Parameters` against the table's specification. It rejects any reference to a field that:
- Is unknown to the table (the `field_lookup` returned `nil`).
- Does not allow the requested capability (e.g. filtering on a column declared with `queryable: :sort`).
- Uses an operator that the column's `filter:` option does not allow.

When validation fails, the [`on_invalid_input`](../README.md#on_invalid_input) configuration decides the outcome:
- `:empty` (default) - Prato returns an empty result (`{ entries: [], totalCount: 0 }` for `.page`, `[]` for `.full`, no yields for `.batches`).
- `:raise` - Prato raises `ArgumentError`.
