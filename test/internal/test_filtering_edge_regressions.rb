# frozen_string_literal: true

require "test_helper"

module FilteringEdgeRegressionHelpers
  private

  def filter(field, operator, value)
    Prato::Query::Filter.new(field, operator, value)
  end

  def names_for(table, filters)
    table.to_table(
      User.order(:id),
      params: Prato::Query::Parameters.new(filters: filters)
    )[:entries].map { |entry| entry[:name] }
  end
end

class TestFilteringEmptyGroupSemantics < Minitest::Test
  include FilteringEdgeRegressionHelpers

  def setup
    @table = Prato.table(User) do
      column(:name)
      configure(on_invalid_input: :raise)
    end
  end

  def test_empty_and_filter_matches_everything
    assert_equal %w[Alice Bob Carol Dave], names_for(@table, Prato::Query::AndFilter.new([]))
  end

  def test_nested_empty_and_filter_preserves_parent_and_branch
    filters = Prato::Query::AndFilter.new([
      filter(:name, :eq, "Alice"),
      Prato::Query::AndFilter.new([])
    ])

    assert_equal ["Alice"], names_for(@table, filters)
  end
end

class TestFilteringMixedEvaluationParityForNullableSqlColumns < Minitest::Test
  include FilteringEdgeRegressionHelpers

  def setup
    @table = Prato.table(User) do
      column(:name)
      column(:company_id)
      column(:company_label, expression: "CASE WHEN users.company_id IS NULL THEN NULL ELSE 'COMPANY' END")
      column(:min_post_title, min: %i[posts title])
      ruby_column(:always_zero, key: :id) do |records, _cache|
        index_records_by_id(records) { 0 }
      end
      configure(on_invalid_input: :raise)
    end
  end

  def assert_same_names_for_pure_and_mixed(filter_expression)
    pure_sql = names_for(@table, filter_expression)
    mixed = names_for(
      @table,
      Prato::Query::AndFilter.new([
        filter_expression,
        filter(:always_zero, :eq, 0)
      ])
    )

    assert_equal pure_sql, mixed
  end

  def test_nullable_direct_column_not_eq_matches_pure_sql_inside_mixed_tree
    assert_same_names_for_pure_and_mixed(filter(:company_id, :not_eq, Company.find_by!(name: "Acme Corp").id))
  end

  def test_nullable_expression_column_not_contains_matches_pure_sql_inside_mixed_tree
    assert_same_names_for_pure_and_mixed(filter(:company_label, :not_contains, "COMP"))
  end

  def test_nullable_aggregate_column_not_eq_matches_pure_sql_inside_mixed_tree
    assert_same_names_for_pure_and_mixed(filter(:min_post_title, :not_eq, "Learning Rails"))
  end
end

class TestFilteringContainsParityAcrossMixedEvaluation < Minitest::Test
  include FilteringEdgeRegressionHelpers

  def setup
    @table = Prato.table(User) do
      column(:name)
      ruby_column(:always_zero, key: :id) do |records, _cache|
        index_records_by_id(records) { 0 }
      end
      configure(on_invalid_input: :raise)
    end
  end

  def test_contains_matches_pure_sql_when_mixed_with_a_ruby_filter
    pure_sql = names_for(@table, filter(:name, :contains, "ali"))
    mixed = names_for(
      @table,
      Prato::Query::AndFilter.new([
        filter(:name, :contains, "ali"),
        filter(:always_zero, :eq, 0)
      ])
    )

    assert_equal pure_sql, mixed
  end

  def test_not_contains_matches_pure_sql_when_mixed_with_a_ruby_filter
    pure_sql = names_for(@table, filter(:name, :not_contains, "ali"))
    mixed = names_for(
      @table,
      Prato::Query::AndFilter.new([
        filter(:name, :not_contains, "ali"),
        filter(:always_zero, :eq, 0)
      ])
    )

    assert_equal pure_sql, mixed
  end
end
