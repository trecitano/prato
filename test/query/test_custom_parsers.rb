# frozen_string_literal: true

require "test_helper"

class FictionalSearchPageParser < Prato::Query::DefaultParser
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
    field = sort.delete_prefix("-")

    [{ field: field, order: is_desc ? "desc" : "asc" }]
  end

  def extract_fields(input)
    input.fetch(:select).split(",")
  end
end

class FictionalMinimalParser
  def parse_parameters(input, field_lookup)
    Prato::Query::Parameters.new(
      page: integer(input.fetch(:p)),
      per_page: integer(input.fetch(:limit)),
      filters: filters(input.fetch(:match), field_lookup),
      sorts: sorts(input.fetch(:order), field_lookup),
      fields: fields(input.fetch(:show), field_lookup)
    )
  end

  private

  def integer(value)
    Integer(value)
  end

  def filters(match, field_lookup)
    field, value = match.split(":", 2)

    [Prato::Query::Filter.new(resolve_field(field, field_lookup), :icontains, value)]
  end

  def sorts(order, field_lookup)
    is_desc = order.start_with?("-")
    field = order.delete_prefix("-")

    [Prato::Query::Sort.new(resolve_field(field, field_lookup), is_desc)]
  end

  def fields(show, field_lookup)
    show.split("|").map { |field| resolve_field(field, field_lookup) }
  end

  def resolve_field(field, field_lookup)
    field_lookup.call(field.split("."))
  end
end

SEARCH_PAGE_INPUT = {
  page_info: { number: "2", size: "25" },
  where: { "profile.companyName" => "Acme Corp" },
  order_by: "-postCount",
  select: "name,profile.agePlusTen"
}.freeze

MINIMAL_INPUT = {
  p: "3",
  limit: "10",
  match: "name:ali",
  order: "age",
  show: "name|profile.companyName"
}.freeze

SEARCH_PAGE_TABLE_INPUT = {
  page_info: { number: "1", size: "2" },
  where: { "active" => true, "profile.companyName" => "Acme Corp" },
  order_by: "-age",
  select: "name,age"
}.freeze

MINIMAL_TABLE_INPUT = {
  p: "1",
  limit: "3",
  match: "name:a",
  order: "-age",
  show: "name|age"
}.freeze

class TestCustomParsers < Minitest::Test
  def test_default_parser_subclasses_can_customize_extraction_hooks
    params = FictionalSearchPageParser.new.parse_parameters(SEARCH_PAGE_INPUT, field_lookup)

    assert_pagination params, 2, 25
    assert_filter params.filters.first, :profile___company_name, :eq, "Acme Corp"
    assert_sort params.sorts.first, :post_count, true
    assert_equal %i[name profile___age_plus_ten], params.fields
  end

  def test_parsers_can_reimplement_parse_parameters_directly
    params = FictionalMinimalParser.new.parse_parameters(MINIMAL_INPUT, field_lookup)

    assert_pagination params, 3, 10
    assert_filter params.filters.first, :name, :icontains, "ali"
    assert_sort params.sorts.first, :age, false
    assert_equal %i[name profile___company_name], params.fields
  end

  def test_default_parser_subclasses_work_when_configured_on_a_table
    result = user_table(FictionalSearchPageParser.new).page(User.all, params: SEARCH_PAGE_TABLE_INPUT)

    assert_equal %w[Alice Bob], result_names(result)
    assert_equal [30, 17], result_ages(result)
    assert_equal 2, result[:totalCount]
  end

  def test_reimplemented_parsers_work_when_configured_on_a_table
    result = user_table(FictionalMinimalParser.new).page(User.all, params: MINIMAL_TABLE_INPUT)

    assert_equal %w[Dave Alice Carol], result_names(result)
    assert_equal [40, 30, 25], result_ages(result)
    assert_equal 3, result[:totalCount]
  end

  private

  def user_table(parser)
    Prato.table(User) do
      configure(parameter_parser: parser)
      column(:name)
      column(:age)
      column(:active)

      section(:profile) do
        column(company_name: %i[company name])
      end
    end
  end

  def result_names(result)
    result[:entries].map { |entry| entry[:name] }
  end

  def result_ages(result)
    result[:entries].map { |entry| entry[:age] }
  end

  def assert_pagination(params, page, per_page)
    assert_instance_of Prato::Query::Parameters, params
    assert_equal page, params.page
    assert_equal per_page, params.per_page
  end

  def assert_filter(filter, field, operator, value)
    assert_equal field, filter.field
    assert_equal operator, filter.operator
    assert_equal value, filter.value
  end

  def assert_sort(sort, field, is_desc)
    assert_equal field, sort.field
    assert_equal is_desc, sort.is_desc
  end

  def field_lookup
    @field_lookup ||= lambda do |fields|
      {
        %w[age] => :age,
        %w[name] => :name,
        %w[postCount] => :post_count,
        %w[profile companyName] => :profile___company_name,
        %w[profile agePlusTen] => :profile___age_plus_ten
      }.fetch(fields)
    end
  end
end
