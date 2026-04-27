# frozen_string_literal: true

require "test_helper"

module BatchingTestHelper
  private

  def collect_batches(table, scope: User.all, params: nil, batch_size: 2)
    batches = []
    table.batches(scope, params, batch_size: batch_size) { |batch| batches << batch }
    batches
  end

  def batch_names(batches)
    batches.map { |batch| batch.map { |entry| entry[:name] } }
  end
end

class TestBatchingSqlOnlyColumns < Minitest::Test
  include BatchingTestHelper

  def setup
    @table = Prato.table(User) do
      column(:name)
      column(:age)
    end
  end

  def test_yields_serialized_entries_in_batches
    assert_equal(
      [
        [
          { name: "Alice", age: 30 },
          { name: "Bob", age: 17 }
        ],
        [
          { name: "Carol", age: 25 },
          { name: "Dave", age: 40 }
        ]
      ],
      collect_batches(@table)
    )
  end

  def test_batch_size_larger_than_result_set_yields_one_batch
    batches = collect_batches(@table, batch_size: 10)

    assert_equal [%w[Alice Bob Carol Dave]], batch_names(batches)
  end

  def test_batch_size_equal_to_result_set_yields_one_batch
    batches = collect_batches(@table, batch_size: 4)

    assert_equal [%w[Alice Bob Carol Dave]], batch_names(batches)
  end

  def test_empty_result_set_does_not_yield_batches
    batches = collect_batches(
      @table,
      params: query_params(filters: query_filter(:name, :eq, "Nobody"))
    )

    assert_equal [], batches
  end

  def test_applies_filters_and_field_selection_to_each_batch
    batches = collect_batches(
      @table,
      params: query_params(fields: :name, filters: query_filter(:age, :gte, 25))
    )

    assert_equal(
      [
        [{ name: "Alice" }, { name: "Carol" }],
        [{ name: "Dave" }]
      ],
      batches
    )
  end

  def test_sql_sorts_do_not_change_active_record_batch_order
    batches = collect_batches(
      @table,
      params: query_params(sorts: [query_sort(:age, :desc)])
    )

    assert_equal [%w[Alice Bob], %w[Carol Dave]], batch_names(batches)
  end

  def test_returns_enumerator_without_block
    enumerator = @table.batches(User.all, batch_size: 3)

    assert_instance_of Enumerator, enumerator
    assert_equal [%w[Alice Bob Carol], ["Dave"]], batch_names(enumerator.to_a)
  end

  def test_invalid_requested_field_does_not_yield_by_default
    batches = collect_batches(
      @table,
      params: query_params(fields: [query_field_path(:name), query_field_path(:unknown_field)])
    )

    assert_equal [], batches
  end

  def test_invalid_requested_field_raises_when_configured_to_raise
    table = Prato.table(User) do
      configure(on_invalid_input: :raise)
      column(:name)
    end

    assert_raises(ArgumentError) do
      table.batches(
        User.all,
        query_params(fields: [query_field_path(:name), query_field_path(:unknown_field)])
      ) { |_batch| }
    end
  end

  def test_invalid_sort_field_does_not_yield_even_though_sorts_are_ignored
    batches = collect_batches(
      @table,
      params: query_params(sorts: [query_sort(:unknown_field, :asc)])
    )

    assert_equal [], batches
  end
end

class TestBatchingSqlDerivedColumns < Minitest::Test
  include BatchingTestHelper

  def test_serializes_association_columns_inside_batches
    table = Prato.table(User) do
      column(:name)
      column(company_name: %i[company name])
    end

    assert_equal(
      [
        [{ name: "Alice", companyName: "Acme Corp" }, { name: "Bob", companyName: "Acme Corp" }],
        [{ name: "Carol", companyName: "Globex" }, { name: "Dave", companyName: nil }]
      ],
      collect_batches(table)
    )
  end

  def test_serializes_expression_and_aggregate_columns_inside_batches
    table = Prato.table(User) do
      column(:name)
      column(:age_plus_ten, expression: "users.age + 10")
      column(:post_count, count: :posts)
    end

    assert_equal(
      [
        [
          { name: "Alice", agePlusTen: 40, postCount: 4 },
          { name: "Bob", agePlusTen: 27, postCount: 2 }
        ],
        [
          { name: "Carol", agePlusTen: 35, postCount: 3 },
          { name: "Dave", agePlusTen: 50, postCount: 0 }
        ]
      ],
      collect_batches(table)
    )
  end

  def test_serializes_section_fields_inside_batches
    table = Prato.table(User) do
      column(:name)
      section(:profile) do
        column(:age)
        column(company_name: %i[company name])
      end
    end

    assert_equal(
      [
        [
          { name: "Alice", profile: { age: 30, companyName: "Acme Corp" } },
          { name: "Bob", profile: { age: 17, companyName: "Acme Corp" } }
        ],
        [
          { name: "Carol", profile: { age: 25, companyName: "Globex" } },
          { name: "Dave", profile: { age: 40, companyName: nil } }
        ]
      ],
      collect_batches(table)
    )
  end

  def test_query_only_column_can_filter_without_being_serialized
    table = Prato.table(User) do
      column(:name)
      query_column(company_name: %i[company name])
    end

    batches = collect_batches(
      table,
      params: query_params(filters: query_filter(:company_name, :eq, "Acme Corp"))
    )

    assert_equal [[{ name: "Alice" }, { name: "Bob" }]], batches
  end
end

class TestBatchingRubyColumns < Minitest::Test
  include BatchingTestHelper

  def test_ruby_column_loads_each_active_record_batch_independently
    loader_calls = []
    table = Prato.table(User) do
      column(:name)
      ruby_column(:name_upcase, key: :id) do |records, _cache|
        loader_calls << records.map(&:name)
        index_records_by_id(records) { |user| user.name.upcase }
      end
    end

    batches = collect_batches(table)

    assert_equal [%w[Alice Bob], %w[Carol Dave]], loader_calls
    assert_equal [%w[Alice Bob], %w[Carol Dave]], batch_names(batches)
    assert_equal "ALICE", batches.first.first[:nameUpcase]
  end

  def test_ruby_filter_materializes_then_slices_matching_entries
    loader_calls = []
    table = Prato.table(User) do
      column(:name)
      ruby_column(:name_upcase, key: :id) do |records, _cache|
        loader_calls << records.map(&:name)
        index_records_by_id(records) { |user| user.name.upcase }
      end
    end

    batches = collect_batches(
      table,
      params: query_params(filters: query_filter(:name_upcase, :eq, "ALICE"))
    )

    assert_equal [%w[Alice Bob Carol Dave]], loader_calls
    assert_equal [["Alice"]], batch_names(batches)
    assert_equal "ALICE", batches.first.first[:nameUpcase]
  end

  def test_ruby_sorts_are_ignored_and_do_not_materialize_before_batching
    loader_calls = []
    table = Prato.table(User) do
      column(:name)
      ruby_column(:post_count, key: :id) do |records, _cache|
        loader_calls << records.map(&:name)
        counts = Post.group(:user_id).count
        index_records_by_id(records) { |user| counts.fetch(user.id, 0) }
      end
    end

    batches = collect_batches(
      table,
      params: query_params(sorts: [query_sort(:post_count, :desc)])
    )

    assert_equal [%w[Alice Bob], %w[Carol Dave]], loader_calls
    assert_equal [%w[Alice Bob], %w[Carol Dave]], batch_names(batches)
  end
end
