# frozen_string_literal: true

require "test_helper"

class TestDefaultParser < Minitest::Test
  def setup
    @parser = Prato::Query::DefaultParser.new
  end

  def test_parse_page_returns_integers_for_numeric_values
    assert_equal 2, @parser.parse_page("2")
    assert_equal 3, @parser.parse_page(3)
    assert_equal(-4, @parser.parse_page("-4"))
  end

  def test_parse_page_returns_nil_for_nil_or_invalid_values
    assert_nil @parser.parse_page(nil)
    assert_nil @parser.parse_page("abc")
    assert_nil @parser.parse_page("2.5")
  end

  def test_parse_per_page_returns_integers_for_numeric_values
    assert_equal 15, @parser.parse_per_page("15")
    assert_equal 20, @parser.parse_per_page(20)
  end

  def test_parse_per_page_returns_nil_for_nil_or_invalid_values
    assert_nil @parser.parse_per_page(nil)
    assert_nil @parser.parse_per_page("abc")
    assert_nil @parser.parse_per_page("2.5")
  end

  def test_parse_field_uses_field_lookup_for_dotted_paths
    assert_equal(
      :post_info___category___parent___name,
      @parser.send(:parse_field, "postInfo.category.parent.name", field_lookup)
    )
  end

  def test_parse_field_uses_field_lookup_for_single_fields
    assert_equal(
      :post_count,
      @parser.send(:parse_field, "postCount", field_lookup)
    )
  end

  def test_parse_filters_accepts_json_strings
    filters = @parser.parse_filters(
      '[{"field":"postInfo.category.name","operator":"eq","value":"Ruby"}]',
      field_lookup
    )

    assert_equal 1, filters.length

    filter = filters.first
    assert_instance_of Prato::Query::Filter, filter
    assert_equal :post_info___category___name, filter.field
    assert_equal :eq, filter.operator
    assert_equal "Ruby", filter.value
  end

  def test_parse_filters_accepts_arrays_of_hashes
    filters = @parser.parse_filters(
      [{ field: "postInfo.category.name", operator: "eq", value: "Ruby" }],
      field_lookup
    )

    assert_equal 1, filters.length
    assert_equal :post_info___category___name, filters.first.field
  end

  def test_parse_filters_accepts_single_filter_hashes
    filters = @parser.parse_filters(query_filter(:name, :eq, "Alice"), field_lookup)

    assert_equal 1, filters.length

    filter = filters.first
    assert_instance_of Prato::Query::Filter, filter
    assert_equal :name, filter.field
    assert_equal :eq, filter.operator
    assert_equal "Alice", filter.value
  end

  def test_parse_filters_accepts_single_group_hashes
    filters = @parser.parse_filters(
      query_or(
        query_filter(:name, :eq, "Alice"),
        query_filter(%i[profile company_name], :eq, "Acme Corp")
      ),
      field_lookup
    )

    assert_equal 1, filters.length
    assert_instance_of Prato::Query::OrFilter, filters.first
    assert_equal %i[name profile___company_name], filters.first.filters.map(&:field)
  end

  def test_parse_filters_accepts_mixed_string_and_symbol_keys_in_nested_groups
    filters = @parser.parse_filters(
      [
        {
          "and" => [
            { "field" => "name", operator: "eq", value: "Alice" },
            {
              or: [
                { field: "profile.companyName", "operator" => "eq", "value" => "Acme Corp" }
              ]
            }
          ]
        }
      ],
      field_lookup
    )

    assert_equal 1, filters.length
    assert_instance_of Prato::Query::AndFilter, filters.first
    assert_equal :name, filters.first.filters.first.field
    assert_instance_of Prato::Query::OrFilter, filters.first.filters.last
    assert_equal :profile___company_name, filters.first.filters.last.filters.first.field
  end

  def test_parse_filters_preserves_false_values_from_json_strings
    filters = @parser.parse_filters(
      '[{"field":"active","operator":"eq","value":false}]',
      field_lookup
    )

    assert_equal 1, filters.length
    assert_equal false, filters.first.value
  end

  def test_parse_filters_supports_nested_groups
    filters = @parser.parse_filters(
      [
        {
          or: [
            { field: "name", operator: "eq", value: "Alice" },
            {
              and: [
                { field: "profile.companyName", operator: "eq", value: "Acme" }
              ]
            }
          ]
        }
      ],
      field_lookup
    )

    assert_equal 1, filters.length
    assert_instance_of Prato::Query::OrFilter, filters.first
    assert_equal 2, filters.first.filters.length
    assert_instance_of Prato::Query::Filter, filters.first.filters.first
    assert_instance_of Prato::Query::AndFilter, filters.first.filters.last
    assert_equal :profile___company_name, filters.first.filters.last.filters.first.field
  end

  def test_parse_filters_returns_nil_for_empty_groups
    filters = @parser.parse_filters(
      [
        { or: [] },
        { and: [] }
      ],
      field_lookup
    )

    assert_nil filters
  end

  def test_parse_filters_ignores_empty_nested_groups
    filters = @parser.parse_filters(
      [
        {
          and: [
            { field: "name", operator: "eq", value: "Alice" },
            { and: [] }
          ]
        }
      ],
      field_lookup
    )

    assert_equal 1, filters.length
    assert_instance_of Prato::Query::AndFilter, filters.first
    assert_equal 1, filters.first.filters.length
    assert_equal :name, filters.first.filters.first.field
  end

  def test_parse_filters_returns_nil_for_nil_input
    assert_nil @parser.parse_filters(nil, field_lookup)
  end

  def test_parse_filters_returns_nil_for_empty_arrays
    assert_nil @parser.parse_filters([], field_lookup)
  end

  def test_parse_filters_raises_when_nesting_exceeds_maximum_depth
    error = assert_raises(ArgumentError) do
      @parser.parse_filters(nest_filter_group(:and, 10, query_filter(:name, :eq, "Alice")), field_lookup)
    end

    assert_equal "Filter nesting too deep (maximum depth: 10)", error.message
  end

  def test_parse_parameters_parses_raw_query_input
    params = @parser.parse_parameters(
      {
        page: "2",
        per_page: "15",
        filters: [{ field: "postInfo.category.name", operator: "eq", value: "Ruby" }],
        sorts: [{ field: "postInfo.category.parent.name", order: "desc" }],
        fields: ["name", "profile.agePlusTen"]
      },
      field_lookup
    )

    assert_equal 2, params.page
    assert_equal 15, params.per_page
    assert_equal :post_info___category___name, params.filters.first.field
    assert_equal :post_info___category___parent___name, params.sorts.first.field
    assert params.sorts.first.is_desc
    assert_equal %i[name profile___age_plus_ten], params.fields
  end

  def test_parse_parameters_accepts_string_keys
    params = @parser.parse_parameters(
      {
        "page" => "2",
        "per_page" => "15",
        "filters" => '[{"field":"active","operator":"eq","value":false}]',
        "sorts" => '[{"field":"postInfo.category.parent.name","order":"desc"}]',
        "fields" => '["name","profile.agePlusTen"]'
      },
      field_lookup
    )

    assert_equal 2, params.page
    assert_equal 15, params.per_page
    assert_equal :active, params.filters.first.field
    assert_equal false, params.filters.first.value
    assert_equal :post_info___category___parent___name, params.sorts.first.field
    assert params.sorts.first.is_desc
    assert_equal %i[name profile___age_plus_ten], params.fields
  end

  def test_parse_fields_accepts_json_strings
    fields = @parser.parse_fields('["name","profile.agePlusTen"]', field_lookup)

    assert_equal %i[name profile___age_plus_ten], fields
  end

  def test_parse_fields_accepts_arrays
    fields = @parser.parse_fields(
      [query_field_path(:name), query_field_path(%i[profile age_plus_ten])],
      field_lookup
    )

    assert_equal %i[name profile___age_plus_ten], fields
  end

  def test_parse_fields_returns_nil_for_nil_input
    assert_nil @parser.parse_fields(nil, field_lookup)
  end

  def test_parse_fields_returns_empty_array_for_empty_arrays
    assert_equal [], @parser.parse_fields([], field_lookup)
  end

  def test_parse_sorts_treats_descending_as_desc
    sorts = @parser.parse_sorts(
      [{ field: "postInfo.category.parent.name", order: "descending" }],
      field_lookup
    )

    assert_equal 1, sorts.length
    assert_equal :post_info___category___parent___name, sorts.first.field
    assert sorts.first.is_desc
  end

  def test_parse_sorts_treats_desc_as_desc
    sorts = @parser.parse_sorts(
      [{ field: "postInfo.category.parent.name", order: "desc" }],
      field_lookup
    )

    assert_equal 1, sorts.length
    assert_equal :post_info___category___parent___name, sorts.first.field
    assert sorts.first.is_desc
  end

  def test_parse_sorts_treats_non_desc_orders_as_ascending
    sorts = @parser.parse_sorts(
      [
        { field: "postInfo.category.parent.name", order: "asc" },
        { field: "postCount", order: "sideways" }
      ],
      field_lookup
    )

    assert_equal 2, sorts.length
    refute sorts.first.is_desc
    refute sorts.last.is_desc
  end

  def test_parse_sorts_accepts_json_strings
    sorts = @parser.parse_sorts(
      '[{"field":"postInfo.category.parent.name","order":"desc"}]',
      field_lookup
    )

    assert_equal 1, sorts.length
    assert_equal :post_info___category___parent___name, sorts.first.field
    assert sorts.first.is_desc
  end

  def test_parse_sorts_accepts_single_hashes
    sorts = @parser.parse_sorts(query_sort(:post_count, :asc), field_lookup)

    assert_equal 1, sorts.length
    assert_equal :post_count, sorts.first.field
    refute sorts.first.is_desc
  end

  def test_parse_sorts_returns_nil_for_nil_input
    assert_nil @parser.parse_sorts(nil, field_lookup)
  end

  def test_parse_sorts_returns_empty_array_for_empty_arrays
    assert_equal [], @parser.parse_sorts([], field_lookup)
  end

  def test_parse_filters_raises_for_invalid_json_string
    assert_raises(JSON::ParserError) do
      @parser.parse_filters('[{"field":"name","operator":"eq","value":"Alice"}', field_lookup)
    end
  end

  def test_parse_filters_raises_for_invalid_top_level_type
    assert_raises(ArgumentError) do
      @parser.parse_filters(123, field_lookup)
    end
  end

  def test_parse_sorts_raises_for_invalid_json_string
    assert_raises(JSON::ParserError) do
      @parser.parse_sorts('[{"field":"name","order":"asc"}', field_lookup)
    end
  end

  def test_parse_sorts_raises_for_invalid_top_level_type
    assert_raises(ArgumentError) do
      @parser.parse_sorts(123, field_lookup)
    end
  end

  def test_parse_fields_raises_for_invalid_json_string
    assert_raises(JSON::ParserError) do
      @parser.parse_fields('["name"', field_lookup)
    end
  end

  def test_parse_fields_raises_for_invalid_top_level_type
    assert_raises(ArgumentError) do
      @parser.parse_fields(123, field_lookup)
    end
  end

  private

  def nest_filter_group(operator, depth, leaf)
    depth.times.reduce(leaf) do |nested, _|
      { operator => [nested] }
    end
  end

  def field_lookup
    @field_lookup ||= lambda do |fields|
      {
        %w[active] => :active,
        %w[name] => :name,
        %w[postCount] => :post_count,
        %w[profile companyName] => :profile___company_name,
        %w[profile agePlusTen] => :profile___age_plus_ten,
        %w[postInfo category name] => :post_info___category___name,
        %w[postInfo category parent name] => :post_info___category___parent___name
      }.fetch(fields)
    end
  end
end
