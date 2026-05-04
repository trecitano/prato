# ![Prato](docs/prato_logo.webp)

[Click here to see the interactive demo!](https://prato.trecitano.com/)

Prato is a library that simplifies the backend code required to support queryable data, 
by mapping parameters onto a table structure, 
allowing Prato to invoke Active Record methods like  `.where`, `.order`, `.joins`, `.pluck` and others.

The immediate use case for this is fetching data for tables in the frontend, 
and with a simple *Prato* table, it becomes trivial to provide any kind of filtering / sorting / pagination operations 
over an Active Record relation.

A quick example of this in action:

```ruby
class BooksController < ApplicationController
  def index
    table = Prato.table(Book) do
      column(:title)

      section(:people) do
        column(author_name: [:author, :name])
        column(editor_name: [:editor, :name])
      end

      column(:review_count, count: :reviews)
      column(:avg_review_score, avg: [:reviews, :score])
    end

    render json: table.page(Book.all, params)
  end
end
```

Assuming Book has an association to `author`, `editor`, and `reviews`, this will generate the following result:
```json lines
{
  "entries": [
    {
      "title": "Practical Object Conversations",
      "people": {
        "authorName": "Sandi Metz",
        "editorName": "Martin Fowler"
      },
      "reviewCount": 2,
      "avgReviewScore": 2.5
    },
    // ... 9 entries omitted
  ],
  "totalCount": 24
}
```

That's it! Even if the request contains parameters (filters, ordering, field selection), 
we don't have to change any of the backend code.

## Table of Contents

- [Why Prato](#why-prato)
- [Requirements](#requirements)
- [Installation](#installation)
- [Technical Overview](#technical-overview)
- [Usage](#usage)
    - [Defining a Prato table](#defining-a-prato-table)
        - [column](#column)
        - [query_column](#query_column)
        - [section](#section)
        - [configuration](#configuration)
        - [ruby_column (Advanced)](#ruby_column-advanced)
    - [Materializing a scope](#materializing-a-scope)
    - [Parameters / Request Details](#parameters--request-details)
        - [Pagination](#pagination)
        - [Filters](#filters)
        - [Sorting](#sorting)
        - [Fields](#fields)
- [Development](#development-todo)
- [Contributing](#contributing)
- [License](#license)


## Why Prato

Prato was born as a way to tackle complexity at scale.

It's common for applications to have some web pages that display data in a tabular style. The default approach to solve this
is to write an Active Record scope, add any necessary `.where` or `.or` statements, add `.includes` for any relations 
and then serialize the result into model objects, as this is more ergonomic than just using `.pluck`.

This has some downsides:
- The request can overfetch data from the database.
  - (which is problematic when new columns are added, and we don't know how much data they might have!)
- The relation is materialized with model objects, which may invoke any number of callbacks that we are not aware of (`after_find` or `after_initialize`).
- The business requirements may change, requiring data from different models which causes association and serializaiton code to be revisited.
- It's necessary to write *a lot* of code. 

For applications being worked on with multiple developers and with hundreds of database tables, it becomes tricky to ensure
that all code is performant and correct.

Prato's table structure offers a way of ensuring that all the problems above stop being a concern.

## Requirements

Prato requires Ruby 2.4 or later, Active Record 5.0 or later, and MySql, Sqlite or Postgres.

The library is actively tested against the following matrix:

| Ruby  | Active Record |
|-------|---------------|
| 2.4.x | 5.0           |
| 2.5.x | 5.1           |
| 2.6.x | 5.2           |
| 2.7.x | 6.0, 6.1      |
| 3.0.x | 7.0           |
| 3.1.x | 7.1           |
| 3.2.x | 7.2, 8.0, 8.1 |
| 3.3.x | 7.2, 8.0, 8.1 |
| 3.4.x | 7.2, 8.0, 8.1 |
| 4.0.x | 7.2, 8.0, 8.1 |

## Installation

Install the gem and add it to your application's Gemfile by running:

```bash
bundle add prato
```

## Technical Overview

Prato's guiding philosophy is that Active Record (AR) is already great at building SQL so Prato relies on it and Arel for generating SQL.

A Prato table specification uses `:symbols` to describe the fields that can be displayed, filtered, and sorted. 
These symbols correspond to the method calls that otherwise would have to be written.
For example, `column(author_name: [:author, :name])` provides the same result as `<object>.author.name`.

By letting the request define what is required, Prato can decide at runtime which Active Record methods should be invoked.
Filters map to `.where` clauses, sorts map to `.order` clauses, association paths add the required joins, pagination adds `.limit` and `.offset`
and finally `.pluck` materializes any data that the request requires.

This lets application offer more functionality while having less code.

## Usage

Prato relies on two steps: 
- Defining a Prato table.
- Use an Active Record relation on that table with `.page(scope, params)`, `.full(scope, params)` or `.batches(scope, params, ...)`.

### Defining a Prato table

A Prato table consists of columns and may also include sections and configuration.
The example below demonstrates many of the available features:

```ruby
table = Prato.table(Book) do
  column(:title)
  column("Display Title" => :title)
  column(:author_name, [:author, :name])
  column(:city, [:publisher, :address, :city])

  column(:review_count, count: :reviews)
  column(:review_sum,   sum:   [:reviews, :score])
  column(:review_avg,   avg:   [:reviews, :score])
  column(:review_min,   min:   [:reviews, :score])
  column(:review_max,   max:   [:reviews, :score])

  column(:title_upper, expression: "UPPER(books.title)")

  column(:formatted_title, :title, format: ->(v) { v.downcase })
  column(:status, filter: [:eq, :in])
  column(:internal_id, :id, queryable: :filter)

  section(:author) do
    column(:name, [:author, :name])
    column(:email, [:author, :email])
  end

  query_column(:author_id, [:author, :id])

  configure(
    key_transformation: :camelCase,
    on_invalid_input: :raise,
    parameter_parser: Prato::Query::DefaultParser,
    default_page_size: 25,
    maximum_page_size: 100,
    default_queryable: :all,
    default_ruby_column_queryable: :none
  )
end
```

Invoking `table.page(Book.all)` will output the following structure:

```ruby
{
  entries: [
    {
      title: "Practical Object Conversations",
      "Display Title" => "Practical Object Conversations",
      authorName: "Sandi Metz",
      city: "Raleigh",
      reviewCount: 4,
      reviewSum: 18,
      reviewAvg: 4.5,
      reviewMin: 3,
      reviewMax: 5,
      titleUpper: "PRACTICAL OBJECT CONVERSATIONS",
      formattedTitle: "practical object conversations",
      status: "published",
      author: {
        name: "Sandi Metz",
        email: "sandi@example.com"
      }
    },
    # ... up to 24 more entries omitted (default_page_size: 25)
  ],
  totalCount: 34
}
```

#### column

A `column` is backed by SQL and its values are obtained via `.pluck`, unless `ruby_columns` are used (see more below). 
Filters and sorts applied to a `column` will generate SQL via Arel or Active Record methods.

The source of a column's value can be defined in different ways:
- A column on the base model, referenced by name.
- A column on an associated model, reached through an association path.
- An aggregate expression (`:count`, `:avg`, `:sum`, `:min`, `:max`).
- A custom SQL expression.

In the following subsections, every example will use the configuration `key_transformation: :camelCase`.

##### Basic Columns

Use a symbol to expose a model column directly:

| Example                    | Output field     | SQL source        |
|----------------------------|------------------|-------------------|
| `column(:release_year)`    | `:releaseYear`   | `release_year`    |
| `column(:runtime_minutes)` | `:runtimeMinutes` | `runtime_minutes` |
| `column(:published_at)`    | `:publishedAt`   | `published_at`    | 

Use a hash when the output field should differ from the source column:

| Example                                     | Output field   | SQL source         |
|---------------------------------------------|----------------|--------------------|
| `column(display_name: :name)`               | `:displayName` | `name`             |
| `column(released_on: :release_date)`        | `:releasedOn`  | `release_date`     |
| `column("Box Office" => :box_office_total)` | `"Box Office"` | `box_office_total` |

Use an association path to read from a joined model:

| Example                                           | Output field       | SQL source          |
|---------------------------------------------------|--------------------|---------------------|
| `column(studio_name: [:studio, :name])`           | `:studioName`      | `studios.name`      |
| `column(director_country: [:director, :country])` | `:directorCountry` | `directors.country` |
| `column("Genre Label" => [:genre, :label])`       | `"Genre Label"`    | `genres.label`      |
| `column(:publisher_city, [:publisher, :city])`    | `:publisherCity`   | `publishers.city`   |

##### Aggregate Columns

Use an aggregate keyword to compute a value in SQL:

| Example                                                    | Output field      | SQL source                  |
|------------------------------------------------------------|-------------------|-----------------------------|
| `column(:review_count, count: :reviews)`                   | `:reviewCount`    | `COUNT(reviews.*)`          |
| `column(:average_rating, avg: [:reviews, :rating])`        | `:averageRating`  | `AVG(reviews.rating)`       |
| `column(:total_sales, sum: [:orders, :total_cents])`       | `:totalSales`     | `SUM(orders.total_cents)`   |
| `column(:first_showtime, min: [:screenings, :starts_at])`  | `:firstShowtime`  | `MIN(screenings.starts_at)` |
| `column(:latest_purchase, max: [:purchases, :created_at])` | `:latestPurchase` | `MAX(purchases.created_at)` |

##### Expression Columns

Use `expression:` when the value should come from custom SQL:

| Example                                                                | Output field      | SQL source                      |
|------------------------------------------------------------------------|-------------------|---------------------------------|
| `column(:lowercase_name, expression: "LOWER(name)")`                   | `:normalizedName` | `LOWER(name)`                   |
| `column(:release_decade, expression: "FLOOR(release_year / 10) * 10")` | `:releaseDecade`  | `FLOOR(release_year / 10) * 10` |
| `column("Short Code", expression: "SUBSTRING(code, 1, 3)")`            | `"Short Code"`    | `SUBSTRING(code, 1, 3)`         |

##### Options

**format**

Use `format:` to transform the raw SQL value before it is serialized.
```ruby
column(:title_length, :title, format: ->(value) { value.length })
```
If the database value for title is "Book title", the serialized value for titleLength will be 10.

**filter**
```ruby
column(:title, filter: [:eq])
```
This column can only be filtered with the `:eq` operator.  
A query that attempts to filter this column with another operator will be treated as invalid input: 
by default it returns an empty result, or raises ArgumentError when on_invalid_input: :raise is configured.

It is also possible to override the filtering behavior.
The proc receives the current relation, the requested operator, and the filter value. 
It must return a relation, or nil to use the default filtering mechanism.
```ruby
column(:age, filter: lambda { |scope, operator, value|
  case operator
  when :eq
    scope.where(age: 10 * value)
  end
})
```
In the example above, only the "equals" operator is overridden. Any other operator will still use the default implementation.
To override filtering and reject all remaining operators, return an empty relation:
```ruby
column(:age, filter: lambda { |scope, operator, value|
  case operator
  when :eq then scope.where(age: 10 * value)
  else scope.none
  end
})
```

##### queryable
Use `queryable` to control whether a column can be filtered or sorted.
```ruby
column(:currency, queryable: :all)      # Can be displayed, filtered and sorted
column(:title, queryable: :none)        # Can only be displayed
column(:status, queryable: :filter)     # Can be displayed and filtered, but not sorted
column(:created_at, queryable: :sort)   # Can be displayed and sorted, but not filtered
```

#### query_column

A `query_column` behaves like a `column`, but it's not included in the serialized output.

Use it when a field should be available for filtering or sorting, but should not be rendered in the response.

```ruby
query_column(:author_id, [:author, :id])
query_column(:status, filter: [:eq])
query_column(:created_at, queryable: :sort)
```
For `query_column`, valid `queryable:` values are `:all`, `:filter`, and `:sort`.

#### section

Use `section` to group fields under a nested object in the serialized output.

```ruby
table = Prato.table(Book) do
  column(:title)
  section(:author) do
    column(:name, [:author, :name])
    column(:email, [:author, :email])
  end
end
```
Invoking `table.page(Book.all)` produces:
```ruby
{
  entries: [
    {
      title: "Practical Object Conversations",
      author: {
        name: "Sandi Metz",
        email: "sandi@example.com"
      }
    }
  ],
  totalCount: 1
}
```
Sections only affect the output shape, nesting together some columns. They can also be nested themselves:
```ruby
section(:publisher) do
  section(:address) do
    column(:city, %i[publisher address city])
  end
end
```
When using the [default parser](lib/prato/query/default_parser.rb), 
nested fields are referenced with dotted paths when filtering, sorting or selecting fields:
```ruby
table.page(
  Book.all,
  {
    filters: [{ field: "author.name", operator: "eq", value: "Sandi Metz" }],
    sorts: [{ field: "author.email", order: "asc" }],
    fields: ["title", "author.name"]
  }
)
```
Section names with symbols are transformed using `key_transformation`.
```ruby
configure(key_transformation: :snake_case)
section(:authorProfile) do
  column(:displayName, %i[author name])
end
```
This serializes as:
```ruby
{
  author_profile: {
    display_name: "Sandi Metz"
  }
}
```

#### configuration

Use `configure` inside a table definition to override the application-level settings.

```ruby
table = Prato.table(Book) do
  column(:title)
  column(:published_at)
  
  configure(
    key_transformation: :camelCase,
    on_invalid_input: :empty,
    parameter_parser: Prato::Query::DefaultParser.new,
    default_page_size: 20,
    maximum_page_size: 100,
    default_queryable: :all,
    default_ruby_column_queryable: :none
  )
end
```
| Option                            | Default                           | Values                                                           |
|-----------------------------------|-----------------------------------|------------------------------------------------------------------|
| `key_transformation`              | `:camelCase`                      | `:camelCase`, `:snake_case`, `:none`                             |
| `on_invalid_input`                | `:empty`                          | `:empty`, `:raise`                                               |
| `parameter_parser`                | `Prato::Query::DefaultParser.new` | Any object responding to `parse_parameters(input, field_lookup)` |
| `default_page_size`               | `20`                              | Integer                                                          |
| `maximum_page_size`               | `100`                             | Integer                                                          |
| `default_queryable`               | `:all`                            | `:all`, `:none`, `:filter`, `:sort`                              |
| `default_ruby_column_queryable`   | `:none`                           | `:all`, `:none`, `:filter`, `:sort`                              |

##### `key_transformation`
Controls how output keys are transformed.

```ruby
configure(key_transformation: :camelCase)
column(:published_at)
# => :publishedAt
configure(key_transformation: :snake_case)
column(:publishedAt, :published_at)
# => :published_at
configure(key_transformation: :none)
column(:published_at)
# => :published_at
```
This applies to both column names and section names that use `:symbols`. Strings are not affected by the key transformation.

##### `on_invalid_input`

Controls what happens when parsed request parameters reference fields or operators that are not allowed.
```ruby
configure(on_invalid_input: :empty)  # returns an empty result
configure(on_invalid_input: :raise)  # raises an `ArgumentError`
```

##### `parameter_parser`
Controls how incoming request parameters are converted into Prato query parameters.
```ruby
configure(parameter_parser: MyCustomParser.new)
```
A custom parser must respond to:
```ruby
parse_parameters(input, field_lookup)
```
It should return a `Prato::Query::Parameters` object.

To define your own Parser, look at [how to implement a request parser](docs/implementing_a_parser.md)

##### `default_page_size` and `maximum_page_size`
Controls pagination defaults and limits.
```ruby
configure(
  default_page_size: 25,
  maximum_page_size: 100
)
```
If the request does not provide `per_page`, Prato uses `default_page_size`. 
If the request asks for more than `maximum_page_size`, Prato caps the page size.

##### `default_queryable`
Sets the default `queryable:` behavior for columns that do not specify it explicitly.
```ruby
configure(default_queryable: :none)
column(:title)
column(:status, queryable: :filter)
column(:currency, queryable: :all)
```
In this example, `title` can not be filtered or sorted, while `status` is allowed to filter. `currency` can be filtered and sorted.

##### `default_ruby_column_queryable`
Same as `default_queryable`, but applied to `ruby_column`.

##### Global configuration

Use `Prato.setup` with a block to configure application-level defaults. 
These defaults are used by tables that do not override them.

```ruby
Prato.setup do |config|
  config.key_transformation = :snake_case
  config.default_page_size = 50
end

table = Prato.table(Book) do
  column(:published_at)
end
# Output key:
# => :published_at
````

##### Shared configuration

Use `Prato.setup` without a block to create a reusable configuration object. 
That object can then be passed to one or more tables.

```ruby
config = Prato.setup
config.key_transformation = :snake_case
config.default_page_size = 50

books_table = Prato.table(Book) do
  configure(config, maximum_page_size: 200)
  column(:published_at)
end

authors_table = Prato.table(Author) do
  configure(config)
  column(:created_at)
end
```

Options passed directly to configure override the shared configuration object for that table.

#### ruby_column (Advanced)

**Warning!**
Requests that use `ruby_columns` requires Active Record objects to be materialized. 
This disables some SQL-only optimizations, such as serializing directly with `.pluck`.

Use `ruby_column` when a value cannot be expressed as a SQL-backed `column`, or when the value should be loaded through Ruby code.

```ruby
table = Prato.table(Book) do
  column(:title)
  ruby_column(:title_length, key: :id) do |books, _loaders|
    books.to_h do |book|
      [book.id, book.title.length]
    end
  end
end
```

The idea behind a `ruby_column` is that sometimes, we need to have some values that cannot be calculated in the database.
(The example above can actually be computed in the database, but let's pretend it cannot!)

The way the `ruby_column` works is that it receives two arguments: an array of model objects and an hash of loaders.
- The array of model objects represent the data that is going to be displayed in the frontend
- The hash of loaders is useful when a `ruby_column` uses data from another `ruby_column`.

**Separate Loaders**

A loader can also be defined separately with ruby_loader. 
This is useful when multiple Ruby columns need to share the same loading logic, 
or when you want to keep the column declaration compact.

```ruby
table = Prato.table(Book) do
  column(:title)
  ruby_column(:review_summary, key: :id)
  
  ruby_loader(:review_summary) do |books, _cache|
    # This prevents a n+1 issue
    review_counts = Review.where(book_id: books.map(&:id)).group(:book_id).count
    books.to_h do |book|
      count = review_counts.fetch(book.id, 0)
      [book.id, "#{count} reviews"]
    end
  end
end
```

The name passed to ruby_column is used as both the output field and the loader name. 
To use a different output field and loader name, pass both:
```ruby
ruby_column(:summary, :review_summary, key: :id)
ruby_loader(:review_summary) do |books, _cache|
# ...
end
```

**key**

By default, `ruby_column` uses the record's id.
```ruby
ruby_column(:availability) do |books, _cache|
  books.to_h { |book| [book.id, "available"] }
end
```

Use a symbol to read a different attribute:
```ruby
ruby_column(:availability, key: :isbn) do |books, _cache|
  Inventory.lookup(books.map(&:isbn))
end
```

Use a proc when the lookup key needs custom logic:
```ruby
ruby_column(:company_status, key: ->(book) { book.publisher&.company_id }) do |books, _cache|
  # ...
end
```

**includes**

Use includes: when the loader needs associations from the materialized records.
```ruby
ruby_column(:publisher_name, key: :id, includes: :publisher) do |books, _cache|
  books.to_h do |book|
    [book.id, book.publisher&.name]
  end
end
```

The association loading can also be declared on a separate loader:
```ruby
ruby_column(:publisher_name, key: :id)
ruby_loader(:publisher_name, includes: :publisher) do |books, _cache|
  books.to_h { |book| [book.id, book.publisher&.name] }
end
```


**cache**

The second block argument is a loader cache. It can be used when one Ruby loader depends on another Ruby loader.
```ruby
table = Prato.table(Book) do
  ruby_column(:review_count, key: :id)
  
  ruby_loader(:review_count) do |books, _cache|
    Review.where(book_id: books.map(&:id)).group(:book_id).count
  end
  ruby_column(:review_summary, key: :id) do |_books, cache|
    counts = cache[:review_count]
    counts.transform_values do |count|
      "#{count} reviews"
    end
  end
end
```
Loader results are memoized, so referencing cache[:review_count] multiple times does not run that loader multiple times.
Additionally, the loaders are lazy loaded, so they can be declared in any order.

** Filtering and Sorting **

Filtering and sorting on `ruby_column` values should be enabled carefully, because they can be expensive.

When a `ruby_column` is only displayed, Prato can still apply SQL-backed filtering, sorting, and pagination before materializing records. 
This keeps the amount of Ruby work limited to the records that are actually being returned.
Filtering or sorting by a `ruby_column` is different.
Since the value only exists in Ruby, Prato must load the matching records, compute the Ruby value for each one, and then apply the filter or sort in memory. 
For large tables, this can mean materializing many records before pagination can be applied.

For this reason, Ruby columns should be treated as display-only by default, and filtering or sorting should only be enabled when the candidate result set is known to be small enough.

### Materializing a scope

There are three ways of materializing a scope - `page`, `full` and `batches`.
All 3 method calls receive the same two main arguments:
- scope: An Active Record relation.
- params: A user-provided object parsed by the configured parameter parser.
  - By default, it's expected that `params` is an `ActionController::Parameters`, but it is not mandatory.
  - This field can be omitted.

```ruby
table = Prato.table(Book) do
  column(:title)
  column(:published_at)
end
```

#### page

Use `page` when returning data for a paginated UI.
`page` applies filters, sorting, field selection, and pagination.
It returns a hash containing the serialized entries and the total number of matching records before pagination:
```ruby
table.page(Book.order(:id), params)
# returns:

{
  entries: [
    {
      title: "Practical Object Conversations",
      publishedAt: "2026-01-01"
    }
  ],
  totalCount: 42
}
```

If no pagination parameters are provided, Prato uses `default_page_size`.

#### full

Use `full` when the entire matching result should be returned.
`full` applies filters, sorting, and field selection, but does not apply pagination and does not return totalCount.
```ruby
table.full(Book.order(:id), params)
# returns:

[
  {
    title: "Practical Object Conversations",
    publishedAt: "2026-01-01"
  },
  {
    title: "Eloquent Ruby",
    publishedAt: "2025-06-15"
  }
]
```

#### batches

Use batches when processing large result sets without loading the whole result into memory at once.
```ruby
table.batches(Book.order(:id), params, batch_size: 1_000) do |batch|
  batch.each do |entry|
    # Process each serialized entry
  end
end
# Each yielded batch is an array of serialized entries:
[
  {
    title: "Practical Object Conversations",
    publishedAt: "2026-01-01"
  }
]
```

If no block is given, batches returns an enumerator:
```ruby
enum = table.batches(Book.order(:id), params, batch_size: 1_000)
enum.each do |batch|
  # Process batch
end
```

batches applies the same filters, sorting, and field selection as full, 
but yields the serialized records in chunks instead of returning a single array.

### Parameters / Request details

Prato receives request data through the `params` argument passed to `.page`, `.full`, or `.batches`.

By default, params are parsed by `Prato::Query::DefaultParser`, which supports pagination, filters, sorting, and field selection.

A custom parser can be configured with `parameter_parser:`, which allows the application to use requests with different parameters and formats.

#### Pagination

- [parameters.rb](lib/prato/query/parameters.rb)
- [parameters.rbs](sig/prato/query/parameters.rbs)

Pagination in prato works by using Active Record's `.offset` and `.limit`.

The [default parser](lib/prato/query/default_parser.rb) reads two optional parameters:

| Parameter  | Meaning                          |
|------------|----------------------------------|
| `page`     | The page number to return        |
| `per_page` | The number of records per page   |


If `page` is not present, then the default page is 1.
If `per_page` is not present, then the used page size is the one in `Configuration.default_page_size`.
If `per_page` is greater than `Configuration.maximum_page_size`, Prato caps it to the configured maximum.

Example Request:
```http request
https://prato.trecitano.com/reviews.json?query={"page":2,"per_page":20}
```
Example params:
```ruby
{
  page: 2,
  per_page: 20
}
```

#### Filters

- [filter.rb](lib/prato/query/filter.rb)
- [filter.rbs](sig/prato/query/filter.rbs)

The following filters are supported:

| Filter                    | Meaning                        |
|---------------------------|--------------------------------|
| `:eq`                     | Equals                         |
| `:not_eq`                 | Not equals                     |
| `:lt`                     | Less than                      |
| `:lte`                    | Less than or equals            |
| `:gt`                     | Greater than                   |
| `:gte`                    | Greater than or equals         |
| `:present`                | Is not nil                     |
| `:not_present`            | Is nil                         |
| `:in`                     | Included in a list             |
| `:not_in`                 | Not included in a list         |
| `:contains`               | Contains, case sensitive       |
| `:not_contains`           | Not contains, case sensitive   |
| `:icontains`              | Contains, case insensitive     |
| `:not_icontains`          | Not contains, case insensitive |
| `:between`                | Between, inclusive             |
| `:not_between`            | Not between, inclusive         |
| `:between_exclusive`      | Between, exclusive             |
| `:not_between_exclusive`  | Not between, exclusive         |

These work by invoking the underlying Arel methods; see the
[filter operator implementation](lib/prato/internal/pipeline/filtering.rb#L138-L160).

The [default parser](lib/prato/query/default_parser.rb) assumes that the request contains a parameter called `filters` 
that contains an array of:
```json
{ 
    "field": "<name of the field>", 
    "operator": "<one of the operators above>",
    "value": "<any value>"
}
```

If `filters` is not present, then no filtering is applied.

```
Example request: 
```http request
http://prato.trecitano.com/nested-relations.json?query={"filters":[{"field":"title","operator":"contains","value":"test2"}]}
```

Filters can also be nested with and and or:
```ruby
{
  filters: [
    {
      or: [
        { field: "title", operator: "contains", value: "ruby" },
        { field: "author.name", operator: "eq", value: "Sandi Metz" }
      ]
    }
  ]
}
```
Nested fields are referenced with dotted paths, matching the serialized output path.

#### Sorting

- [sort.rb](lib/prato/query/sort.rb)
- [sort.rbs](sig/prato/query/sort.rbs)

Prato's Sort objects are composed by 2 parameters:
- :field, the internal name of a field
- :is_desc

The default parser assumes that the request contains a parameter called "sorts" that contains an array of:
```
{
    "field": <name of the field>,
    "order": asc | desc
}
```

If "sorts" is not present, then no sorting is applied.

Example request:
```http request
http://localhost:3000/nested-relations.json?query={"sorts":[{"field":"title","order":"asc"}]}
```

Nested fields can be sorted with dotted paths:
```ruby
{
  sorts: [
    {
      field: "author.name",
      order: "asc"
    }
  ]
}
```

#### Fields

- [parameters.rb](lib/prato/query/parameters.rb)
- [parameters.rbs](sig/prato/query/parameters.rbs)

Field selection controls which fields are included in the serialized response.

The default parser expects fields to contain an array of field names:
```ruby
{
  fields: ["title", "author.name", "avgReviewScore"]
}
```

If fields is not present, every displayable field is included in the response.

Fields inside sections are referenced with dotted paths:
```ruby
{
  fields: ["title", "classification.categoryName", "avgReviewScore"]
}
```
Field selection only affects the serialized output. Fields declared with query_column can still be used for filtering or sorting, but are never rendered.

Example request:
```http request
http://localhost:3000/nested-relations.json?query={"fields":["title","classification.categoryName","avgReviewScore"]}
```

## Development (TODO)

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/run-test-matrix` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/trecitano/prato.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
