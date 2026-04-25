# frozen_string_literal: true

require "test_helper"

module SortingUnitsTestHelper
  private

  def names_for(table, scope: User.all, params: nil)
    table.full(scope, params: params)[:entries].map { |entry| entry[:name] }
  end

  def titles_for(table, scope: Post.all, params: nil)
    table.full(scope, params: params)[:entries].map { |entry| entry[:title] }
  end

  def sorted_names(table, *sorts, scope: User.all, **sort)
    sorts << sort unless sort.empty?
    names_for(table, scope: scope, params: query_params(sorts: sorts))
  end

  def sorted_titles(table, *sorts, scope: Post.all, **sort)
    sorts << sort unless sort.empty?
    titles_for(table, scope: scope, params: query_params(sorts: sorts))
  end
end

class TestSortingDirectColumns < Minitest::Test
  include SortingUnitsTestHelper

  def test_direct_column_sort_orders_records_ascending
    table = Prato.table(User) do
      column(:name)
      column(:age)
    end

    assert_equal %w[Bob Carol Alice Dave], sorted_names(table, query_sort(:age, :asc))
  end
end

class TestSortingAssociationColumns < Minitest::Test
  include SortingUnitsTestHelper

  def test_association_column_sort_orders_posts_by_author_name_then_title
    table = Prato.table(Post) do
      column(:title)
      column(author_name: %i[user name])
    end

    assert_equal(
      [
        "Draft",
        "Hello",
        "More Ruby",
        "Ruby tips",
        "Learning Rails",
        "Young dev",
        "Finance tips",
        "Market update",
        "Unpublished"
      ],
      sorted_titles(table, query_sort(:author_name, :asc), query_sort(:title, :asc))
    )
  end

  def test_multiple_sql_sorts_apply_in_order
    table = Prato.table(User) do
      column(:name)
      column(company_name: %i[company name])
    end

    assert_equal(
      %w[Bob Alice Carol],
      sorted_names(
        table,
        query_sort(:company_name, :asc),
        query_sort(:name, :desc),
        scope: User.where.not(company_id: nil)
      )
    )
  end
end

class TestSortingExpressionColumns < Minitest::Test
  include SortingUnitsTestHelper

  def test_expression_column_sort_orders_records_descending
    table = Prato.table(User) do
      column(:name)
      column(:age_plus_ten, expression: "users.age + 10")
    end

    assert_equal %w[Dave Alice Carol Bob], sorted_names(table, query_sort(:age_plus_ten, :desc))
  end
end

class TestSortingAggregateColumns < Minitest::Test
  include SortingUnitsTestHelper

  def test_count_aggregate_column_sort_orders_records_descending
    table = Prato.table(User) do
      column(:name)
      column(:post_count, count: :posts)
    end

    assert_equal %w[Alice Carol Bob Dave], sorted_names(table, query_sort(:post_count, :desc))
  end

  def test_sum_aggregate_column_sort_orders_records_descending
    table = Prato.table(User) do
      column(:name)
      column(:post_score, sum: %i[posts score])
    end

    assert_equal %w[Alice Carol Bob Dave], sorted_names(table, query_sort(:post_score, :desc))
  end

  def test_avg_aggregate_column_sort_orders_records_descending
    table = Prato.table(User) do
      column(:name)
      column(:avg_post_score, avg: %i[posts score])
    end

    assert_equal(
      %w[Alice Carol Bob],
      sorted_names(
        table,
        query_sort(:avg_post_score, :desc),
        scope: users_with_posts_scope
      )
    )
  end

  def test_min_aggregate_column_sort_orders_records_with_secondary_sort_for_ties
    table = Prato.table(User) do
      column(:name)
      column(:min_post_score, min: %i[posts score])
    end

    assert_equal(
      %w[Bob Carol Alice],
      sorted_names(
        table,
        query_sort(:min_post_score, :asc),
        query_sort(:name, :desc),
        scope: users_with_posts_scope
      )
    )
  end

  def test_max_aggregate_column_sort_orders_records_with_secondary_sort_for_ties
    table = Prato.table(User) do
      column(:name)
      column(:max_post_score, max: %i[posts score])
    end

    assert_equal(
      %w[Alice Carol Bob],
      sorted_names(
        table,
        query_sort(:max_post_score, :desc),
        query_sort(:name, :asc),
        scope: users_with_posts_scope
      )
    )
  end

  private

  def users_with_posts_scope
    User.where(id: Post.select(:user_id).distinct)
  end
end

class TestSortingRubyColumns < Minitest::Test
  include SortingUnitsTestHelper

  def test_ruby_column_sort_orders_records_descending
    table = Prato.table(User) do
      column(:name)
      ruby_column(:post_count, key: :id)

      ruby_loader(:post_count) do |records, _cache|
        counts = Post.group(:user_id).count
        index_records_by_id(records) { |user| counts.fetch(user.id, 0) }
      end
    end

    assert_equal(
      %w[Alice Carol Bob Dave],
      names_for(table, params: query_params(sorts: [query_sort(:post_count, :desc)]))
    )
  end

  def test_ruby_sort_handles_nil_values_consistently
    table = Prato.table(User) do
      column(:name)
      ruby_column(:company_name, key: :id)

      ruby_loader(:company_name, includes: :company) do |records, _cache|
        index_records_by_id(records) { |user| user.company&.name }
      end
    end

    assert_equal(
      %w[Dave Carol Alice Bob],
      names_for(
        table,
        params: query_params(sorts: [query_sort(:company_name, :desc), query_sort(:name, :asc)])
      )
    )
  end

  def test_mixed_ruby_and_sql_sorts_are_evaluated_together
    table = Prato.table(User) do
      column(:name)
      column(:age)
      ruby_column(:company_name, key: :id)

      ruby_loader(:company_name, includes: :company) do |records, _cache|
        index_records_by_id(records) { |user| user.company&.name }
      end
    end

    assert_equal(
      %w[Alice Bob Carol Dave],
      names_for(
        table,
        params: query_params(sorts: [query_sort(:company_name, :asc), query_sort(:age, :desc)])
      )
    )
  end
end

class TestSortingRubyColumnIncludes < Minitest::Test
  include SortingUnitsTestHelper

  def test_ruby_sort_can_use_includes_when_sort_field_is_not_displayed
    table = Prato.table(User) do
      column(:name)
      ruby_column(:company_name, key: :id, includes: :company)

      ruby_loader(:company_name) do |records, _cache|
        index_records_by_id(records) { |user| user.company&.name }
      end
    end

    result = table.full(
      User.order(:id),
      params: query_params(fields: :name, sorts: [query_sort(:company_name, :asc), query_sort(:name, :asc)])
    )

    assert_equal %w[Alice Bob Carol Dave], result[:entries].map { |entry| entry[:name] }
    assert(result[:entries].all? { |entry| entry.keys == [:name] })
  end
end

class TestSortingQueryOnlyColumnsAndValidation < Minitest::Test
  include SortingUnitsTestHelper

  def test_query_column_can_sort_without_serializing_query_only_field
    table = Prato.table(Post) do
      column(:title)
      query_column(author_name: %i[user name])
    end

    result = table.full(
      Post.all,
      params: query_params(sorts: [query_sort(:author_name, :asc), query_sort(:title, :asc)])
    )

    assert_equal(
      [
        "Draft",
        "Hello",
        "More Ruby",
        "Ruby tips",
        "Learning Rails",
        "Young dev",
        "Finance tips",
        "Market update",
        "Unpublished"
      ],
      result[:entries].map { |entry| entry[:title] }
    )
    assert(result[:entries].all? { |entry| entry.keys == [:title] })
  end

  def test_sorting_on_display_only_column_returns_empty_result_by_default
    table = Prato.table(User) do
      column(:name, only: :display)
    end

    result = table.full(
      User.all,
      params: query_params(sorts: [query_sort(:name, :asc)])
    )

    assert_equal [], result[:entries]
    assert_equal 0, result[:totalCount]
  end

  def test_sorting_on_display_only_column_raises_when_invalid_input_is_configured_to_raise
    table = Prato.table(User) do
      configure(on_invalid_input: :raise)
      column(:name, only: :display)
    end

    assert_raises(ArgumentError) do
      table.full(
        User.all,
        params: query_params(sorts: [query_sort(:name, :asc)])
      )
    end
  end
end
