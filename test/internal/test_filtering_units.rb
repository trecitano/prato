# frozen_string_literal: true

require "test_helper"

module FilteringUnitsTestCases
  NORMAL_CASES = {
    eq: { field: :name, value: "Bob", expected_names: ["Bob"] },
    not_eq: { field: :name, value: "Bob", expected_names: %w[Alice Carol Dave] },
    lt: { field: :age, value: 25, expected_names: ["Bob"] },
    lte: { field: :age, value: 25, expected_names: %w[Bob Carol] },
    gt: { field: :age, value: 25, expected_names: %w[Alice Dave] },
    gte: { field: :age, value: 30, expected_names: %w[Alice Dave] },
    present: { field: :company_name, value: nil, expected_names: %w[Alice Bob Carol] },
    not_present: { field: :company_name, value: nil, expected_names: ["Dave"] },
    in: { field: :name, value: %w[Alice Dave], expected_names: %w[Alice Dave] },
    not_in: { field: :name, value: %w[Alice Dave], expected_names: %w[Bob Carol] },
    contains: { field: :name, value: "li", expected_names: ["Alice"] },
    not_contains: { field: :name, value: "li", expected_names: %w[Bob Carol Dave] },
    between: { field: :age, value: [20, 30], expected_names: %w[Alice Carol] },
    not_between: { field: :age, value: [20, 30], expected_names: %w[Bob Dave] },
    between_exclusive: { field: :age, value: [20, 40], expected_names: %w[Alice Carol] },
    not_between_exclusive: { field: :age, value: [20, 30], expected_names: %w[Alice Bob Dave] }
  }.freeze

  AGGREGATE_CASES = {
    eq: { field: :post_count, value: 0, expected_names: ["Dave"] },
    not_eq: { field: :post_count, value: 0, expected_names: %w[Alice Bob Carol] },
    lt: { field: :post_count, value: 2, expected_names: ["Dave"] },
    lte: { field: :post_count, value: 2, expected_names: %w[Bob Dave] },
    gt: { field: :post_count, value: 2, expected_names: %w[Alice Carol] },
    gte: { field: :post_count, value: 3, expected_names: %w[Alice Carol] },
    present: { field: :min_post_title, value: nil, expected_names: %w[Alice Bob Carol] },
    not_present: { field: :min_post_title, value: nil, expected_names: ["Dave"] },
    in: { field: :post_count, value: [0, 2], expected_names: %w[Bob Dave] },
    not_in: { field: :post_count, value: [0, 2], expected_names: %w[Alice Carol] },
    contains: { field: :min_post_title, value: "Rails", expected_names: ["Bob"] },
    not_contains: { field: :min_post_title, value: "Rails", expected_names: %w[Alice Carol] },
    between: { field: :post_count, value: [2, 3], expected_names: %w[Bob Carol] },
    not_between: { field: :post_count, value: [2, 3], expected_names: %w[Alice Dave] },
    between_exclusive: { field: :post_count, value: [1, 4], expected_names: %w[Bob Carol] },
    not_between_exclusive: { field: :post_count, value: [1, 3], expected_names: %w[Alice Carol Dave] }
  }.freeze

  EXPRESSION_CASES = {
    eq: { field: :name_upcase, value: "BOB", expected_names: ["Bob"] },
    not_eq: { field: :name_upcase, value: "BOB", expected_names: %w[Alice Carol Dave] },
    lt: { field: :age_plus_ten, value: 30, expected_names: ["Bob"] },
    lte: { field: :age_plus_ten, value: 35, expected_names: %w[Bob Carol] },
    gt: { field: :age_plus_ten, value: 35, expected_names: %w[Alice Dave] },
    gte: { field: :age_plus_ten, value: 40, expected_names: %w[Alice Dave] },
    present: { field: :company_label, value: nil, expected_names: %w[Alice Bob Carol] },
    not_present: { field: :company_label, value: nil, expected_names: ["Dave"] },
    in: { field: :name_upcase, value: %w[ALICE DAVE], expected_names: %w[Alice Dave] },
    not_in: { field: :name_upcase, value: %w[ALICE DAVE], expected_names: %w[Bob Carol] },
    contains: { field: :name_upcase, value: "AL", expected_names: ["Alice"] },
    not_contains: { field: :name_upcase, value: "AL", expected_names: %w[Bob Carol Dave] },
    between: { field: :age_plus_ten, value: [30, 40], expected_names: %w[Alice Carol] },
    not_between: { field: :age_plus_ten, value: [30, 40], expected_names: %w[Bob Dave] },
    between_exclusive: { field: :age_plus_ten, value: [30, 50], expected_names: %w[Alice Carol] },
    not_between_exclusive: { field: :age_plus_ten, value: [30, 40], expected_names: %w[Alice Bob Dave] }
  }.freeze

  RUBY_CASES = {
    eq: { field: :name_upcase, value: "BOB", expected_names: ["Bob"] },
    not_eq: { field: :name_upcase, value: "BOB", expected_names: %w[Alice Carol Dave] },
    lt: { field: :post_count, value: 2, expected_names: ["Dave"] },
    lte: { field: :post_count, value: 2, expected_names: %w[Bob Dave] },
    gt: { field: :post_count, value: 2, expected_names: %w[Alice Carol] },
    gte: { field: :post_count, value: 3, expected_names: %w[Alice Carol] },
    present: { field: :company_name, value: nil, expected_names: %w[Alice Bob Carol] },
    not_present: { field: :company_name, value: nil, expected_names: ["Dave"] },
    in: { field: :name_upcase, value: %w[ALICE DAVE], expected_names: %w[Alice Dave] },
    not_in: { field: :name_upcase, value: %w[ALICE DAVE], expected_names: %w[Bob Carol] },
    contains: { field: :name_upcase, value: "AL", expected_names: ["Alice"] },
    not_contains: { field: :name_upcase, value: "AL", expected_names: %w[Bob Carol Dave] },
    between: { field: :post_count, value: [2, 3], expected_names: %w[Bob Carol] },
    not_between: { field: :post_count, value: [2, 3], expected_names: %w[Alice Dave] },
    between_exclusive: { field: :post_count, value: [1, 4], expected_names: %w[Bob Carol] },
    not_between_exclusive: { field: :post_count, value: [1, 3], expected_names: %w[Alice Carol Dave] }
  }.freeze

  NORMAL_SECTION_CASES = {
    eq: { field: %i[profile name], value: "Bob", expected_names: ["Bob"] },
    not_eq: { field: %i[profile name], value: "Bob", expected_names: %w[Alice Carol Dave] },
    lt: { field: %i[profile age], value: 25, expected_names: ["Bob"] },
    lte: { field: %i[profile age], value: 25, expected_names: %w[Bob Carol] },
    gt: { field: %i[profile age], value: 25, expected_names: %w[Alice Dave] },
    gte: { field: %i[profile age], value: 30, expected_names: %w[Alice Dave] },
    present: { field: %i[profile company_name], value: nil, expected_names: %w[Alice Bob Carol] },
    not_present: { field: %i[profile company_name], value: nil, expected_names: ["Dave"] },
    in: { field: %i[profile name], value: %w[Alice Dave], expected_names: %w[Alice Dave] },
    not_in: { field: %i[profile name], value: %w[Alice Dave], expected_names: %w[Bob Carol] },
    contains: { field: %i[profile name], value: "li", expected_names: ["Alice"] },
    not_contains: { field: %i[profile name], value: "li", expected_names: %w[Bob Carol Dave] },
    between: { field: %i[profile age], value: [20, 30], expected_names: %w[Alice Carol] },
    not_between: { field: %i[profile age], value: [20, 30], expected_names: %w[Bob Dave] },
    between_exclusive: { field: %i[profile age], value: [20, 40], expected_names: %w[Alice Carol] },
    not_between_exclusive: { field: %i[profile age], value: [20, 30], expected_names: %w[Alice Bob Dave] }
  }.freeze

  AGGREGATE_SECTION_CASES = {
    eq: { field: %i[stats post_count], value: 0, expected_names: ["Dave"] },
    not_eq: { field: %i[stats post_count], value: 0, expected_names: %w[Alice Bob Carol] },
    lt: { field: %i[stats post_count], value: 2, expected_names: ["Dave"] },
    lte: { field: %i[stats post_count], value: 2, expected_names: %w[Bob Dave] },
    gt: { field: %i[stats post_count], value: 2, expected_names: %w[Alice Carol] },
    gte: { field: %i[stats post_count], value: 3, expected_names: %w[Alice Carol] },
    present: { field: %i[stats min_post_title], value: nil, expected_names: %w[Alice Bob Carol] },
    not_present: { field: %i[stats min_post_title], value: nil, expected_names: ["Dave"] },
    in: { field: %i[stats post_count], value: [0, 2], expected_names: %w[Bob Dave] },
    not_in: { field: %i[stats post_count], value: [0, 2], expected_names: %w[Alice Carol] },
    contains: { field: %i[stats min_post_title], value: "Rails", expected_names: ["Bob"] },
    not_contains: { field: %i[stats min_post_title], value: "Rails", expected_names: %w[Alice Carol] },
    between: { field: %i[stats post_count], value: [2, 3], expected_names: %w[Bob Carol] },
    not_between: { field: %i[stats post_count], value: [2, 3], expected_names: %w[Alice Dave] },
    between_exclusive: { field: %i[stats post_count], value: [1, 4], expected_names: %w[Bob Carol] },
    not_between_exclusive: { field: %i[stats post_count], value: [1, 3], expected_names: %w[Alice Carol Dave] }
  }.freeze

  EXPRESSION_SECTION_CASES = {
    eq: { field: %i[computed name_upcase], value: "BOB", expected_names: ["Bob"] },
    not_eq: { field: %i[computed name_upcase], value: "BOB", expected_names: %w[Alice Carol Dave] },
    lt: { field: %i[computed age_plus_ten], value: 30, expected_names: ["Bob"] },
    lte: { field: %i[computed age_plus_ten], value: 35, expected_names: %w[Bob Carol] },
    gt: { field: %i[computed age_plus_ten], value: 35, expected_names: %w[Alice Dave] },
    gte: { field: %i[computed age_plus_ten], value: 40, expected_names: %w[Alice Dave] },
    present: { field: %i[computed company_label], value: nil, expected_names: %w[Alice Bob Carol] },
    not_present: { field: %i[computed company_label], value: nil, expected_names: ["Dave"] },
    in: { field: %i[computed name_upcase], value: %w[ALICE DAVE], expected_names: %w[Alice Dave] },
    not_in: { field: %i[computed name_upcase], value: %w[ALICE DAVE], expected_names: %w[Bob Carol] },
    contains: { field: %i[computed name_upcase], value: "AL", expected_names: ["Alice"] },
    not_contains: { field: %i[computed name_upcase], value: "AL", expected_names: %w[Bob Carol Dave] },
    between: { field: %i[computed age_plus_ten], value: [30, 40], expected_names: %w[Alice Carol] },
    not_between: { field: %i[computed age_plus_ten], value: [30, 40], expected_names: %w[Bob Dave] },
    between_exclusive: { field: %i[computed age_plus_ten], value: [30, 50], expected_names: %w[Alice Carol] },
    not_between_exclusive: { field: %i[computed age_plus_ten], value: [30, 40], expected_names: %w[Alice Bob Dave] }
  }.freeze

  RUBY_SECTION_CASES = {
    eq: { field: %i[computed name_upcase], value: "BOB", expected_names: ["Bob"] },
    not_eq: { field: %i[computed name_upcase], value: "BOB", expected_names: %w[Alice Carol Dave] },
    lt: { field: %i[computed post_count], value: 2, expected_names: ["Dave"] },
    lte: { field: %i[computed post_count], value: 2, expected_names: %w[Bob Dave] },
    gt: { field: %i[computed post_count], value: 2, expected_names: %w[Alice Carol] },
    gte: { field: %i[computed post_count], value: 3, expected_names: %w[Alice Carol] },
    present: { field: %i[computed company_name], value: nil, expected_names: %w[Alice Bob Carol] },
    not_present: { field: %i[computed company_name], value: nil, expected_names: ["Dave"] },
    in: { field: %i[computed name_upcase], value: %w[ALICE DAVE], expected_names: %w[Alice Dave] },
    not_in: { field: %i[computed name_upcase], value: %w[ALICE DAVE], expected_names: %w[Bob Carol] },
    contains: { field: %i[computed name_upcase], value: "AL", expected_names: ["Alice"] },
    not_contains: { field: %i[computed name_upcase], value: "AL", expected_names: %w[Bob Carol Dave] },
    between: { field: %i[computed post_count], value: [2, 3], expected_names: %w[Bob Carol] },
    not_between: { field: %i[computed post_count], value: [2, 3], expected_names: %w[Alice Dave] },
    between_exclusive: { field: %i[computed post_count], value: [1, 4], expected_names: %w[Bob Carol] },
    not_between_exclusive: { field: %i[computed post_count], value: [1, 3], expected_names: %w[Alice Carol Dave] }
  }.freeze
end

module FilteringUnitsTestHelper
  private

  def assert_filter_names(table, field:, operator:, value:, expected_names:)
    result = filtered_result(table, field, operator, value)

    assert_equal expected_names.sort, result[:entries].map { |entry| entry[:name] }.sort
    assert_equal expected_names.length, result[:totalCount]
  end

  def filtered_result(table, field, operator, value)
    filter = Prato::Query::Filter.new(resolve_field(field), operator, value)

    table.to_table(
      User.order(:id),
      params: Prato::Query::Parameters.new(filters: filter)
    )
  end

  def resolve_field(field)
    field.is_a?(Array) ? Prato::Query::FieldPath.join(field) : field
  end
end

module FilteringUnitsTestDefinitions
  def define_filter_operator_tests(test_cases)
    test_cases.each do |operator, test_case|
      define_method("test_filter_#{operator}") do
        assert_filter_names(
          @table,
          field: test_case[:field],
          operator: operator,
          value: test_case[:value],
          expected_names: test_case[:expected_names]
        )
      end
    end
  end
end

class TestFilteringSqlNormalColumns < Minitest::Test
  extend FilteringUnitsTestDefinitions
  include FilteringUnitsTestHelper

  def setup
    @table = Prato.table(User) do
      column(:name)
      column(:age)
      column(company_name: %i[company name])
    end
  end

  define_filter_operator_tests FilteringUnitsTestCases::NORMAL_CASES
end

class TestFilteringSqlAggregateColumns < Minitest::Test
  extend FilteringUnitsTestDefinitions
  include FilteringUnitsTestHelper

  def setup
    @table = Prato.table(User) do
      column(:name)
      column(:post_count, count: :posts)
      column(:min_post_title, min: %i[posts title])
    end
  end

  define_filter_operator_tests FilteringUnitsTestCases::AGGREGATE_CASES
end

class TestFilteringSqlExpressionColumns < Minitest::Test
  extend FilteringUnitsTestDefinitions
  include FilteringUnitsTestHelper

  def setup
    @table = Prato.table(User) do
      column(:name)
      column(:age_plus_ten, expression: "users.age + 10")
      column(:name_upcase, expression: "UPPER(users.name)")
      column(:company_label, expression: "CASE WHEN users.company_id IS NULL THEN NULL ELSE 'COMPANY' END")
    end
  end

  define_filter_operator_tests FilteringUnitsTestCases::EXPRESSION_CASES
end

class TestFilteringRubyColumns < Minitest::Test
  extend FilteringUnitsTestDefinitions
  include FilteringUnitsTestHelper

  def setup
    @table = Prato.table(User) do
      column(:name)
      ruby_column(:post_count, key: :id)
      ruby_column(:name_upcase, key: :id)
      ruby_column(:company_name, key: :id)

      ruby_loader(:post_count) do |records, _cache|
        counts = Post.group(:user_id).count
        records.index_by(&:id).transform_values { |user| counts.fetch(user.id, 0) }
      end

      ruby_loader(:name_upcase) do |records, _cache|
        records.index_by(&:id).transform_values { |user| user.name.upcase }
      end

      ruby_loader(:company_name) do |records, _cache|
        records.index_by(&:id).transform_values { |user| user.company&.name }
      end
    end
  end

  define_filter_operator_tests FilteringUnitsTestCases::RUBY_CASES
end

class TestFilteringSqlNormalColumnsSection < Minitest::Test
  extend FilteringUnitsTestDefinitions
  include FilteringUnitsTestHelper

  def setup
    @table = Prato.table(User) do
      column(:name)
      section(:profile) do
        column(:name)
        column(:age)
        column(company_name: %i[company name])
      end
    end
  end

  define_filter_operator_tests FilteringUnitsTestCases::NORMAL_SECTION_CASES
end

class TestFilteringSqlAggregateColumnsSection < Minitest::Test
  extend FilteringUnitsTestDefinitions
  include FilteringUnitsTestHelper

  def setup
    @table = Prato.table(User) do
      column(:name)
      section(:stats) do
        column(:post_count, count: :posts)
        column(:min_post_title, min: %i[posts title])
      end
    end
  end

  define_filter_operator_tests FilteringUnitsTestCases::AGGREGATE_SECTION_CASES
end

class TestFilteringSqlExpressionColumnsSection < Minitest::Test
  extend FilteringUnitsTestDefinitions
  include FilteringUnitsTestHelper

  def setup
    @table = Prato.table(User) do
      column(:name)
      section(:computed) do
        column(:age_plus_ten, expression: "users.age + 10")
        column(:name_upcase, expression: "UPPER(users.name)")
        column(:company_label, expression: "CASE WHEN users.company_id IS NULL THEN NULL ELSE 'COMPANY' END")
      end
    end
  end

  define_filter_operator_tests FilteringUnitsTestCases::EXPRESSION_SECTION_CASES
end

class TestFilteringRubyColumnsSection < Minitest::Test
  extend FilteringUnitsTestDefinitions
  include FilteringUnitsTestHelper

  def setup
    @table = Prato.table(User) do
      column(:name)
      section(:computed) do
        ruby_column(:post_count, key: :id) do |records, _cache|
          counts = Post.group(:user_id).count
          records.index_by(&:id).transform_values { |user| counts.fetch(user.id, 0) }
        end
        ruby_column(:name_upcase, key: :id) do |records, _cache|
          records.index_by(&:id).transform_values { |user| user.name.upcase }
        end
        ruby_column(:company_name, key: :id) do |records, _cache|
          records.index_by(&:id).transform_values { |user| user.company&.name }
        end
      end
    end
  end

  define_filter_operator_tests FilteringUnitsTestCases::RUBY_SECTION_CASES
end
