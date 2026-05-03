# frozen_string_literal: true

require "test_helper"

class TestApiQueryColumnFiltering < Minitest::Test
  def test_query_column_can_filter_without_serializing_query_only_field
    table = Prato.table(Post) do
      column(:title)
      query_column(author_name: %i[user name])
    end

    result = table.full(
      Post.order(:id),
      query_params(filters: query_filter(:author_name, :eq, "Alice"))
    )

    assert_equal(["Hello", "Draft", "Ruby tips", "More Ruby"], result.map { |entry| entry[:title] })
    assert(result.all? { |entry| entry.keys == [:title] })
  end

  def test_query_column_has_many_filters_duplicates_rows_or_total_count
    table = Prato.table(Post) do
      column(:title)
      query_column(tag_name: %i[tags name])
    end

    result = table.page(
      Post.order(:id),
      query_params(page: 1, per_page: 10, filters: query_filter(:tag_name, :in, %w[rails ruby]))
    )

    assert_equal ["Hello", "Hello", "Young dev"], result[:entries].map { |entry| entry[:title] }.sort
    assert_equal 3, result[:totalCount]
  end

  # The library does not handle distincts
  def test_query_column_has_many_or_filters_duplicates_rows_or_total_count
    table = Prato.table(Post) do
      column(:id)
      column(:title)
      column(tag_name: %i[tags name])
    end

    result = table.page(
      Post.order(:id),
      query_params(
        page: 1,
        per_page: 10,
        filters: query_or(
          query_filter(:tag_name, :eq, "rails"),
          query_filter(:tag_name, :eq, "ruby")
        )
      )
    )

    assert_equal ["Hello", "Hello", "Young dev"], result[:entries].map { |entry| entry[:title] }.sort
    assert_equal 3, result[:totalCount]
  end

  def test_query_column_array_filter_allowlist_allows_icontains_default_filtering
    table = Prato.table(Post) do
      column(:title)
      query_column(author_name: %i[user name], filter: %i[eq icontains])
    end

    result = table.full(
      Post.order(:id),
      query_params(filters: query_filter(:author_name, :icontains, "ALI"))
    )

    assert_equal(["Hello", "Draft", "Ruby tips", "More Ruby"], result.map { |entry| entry[:title] })
  end

  def test_query_column_array_filter_allowlist_rejects_other_operators
    table = Prato.table(Post) do
      column(:title)
      query_column(author_name: %i[user name], filter: %i[eq])
    end

    result = table.full(
      Post.order(:id),
      query_params(filters: query_filter(:author_name, :contains, "Ali"))
    )

    assert_equal [], result
  end
end

class TestApiDisplayOnlyColumnFiltering < Minitest::Test
  def test_filtering_on_display_only_column_returns_empty_result_by_default
    table = Prato.table(User) do
      column(:name, queryable: :none)
    end

    result = table.full(
      User.order(:id),
      query_params(filters: query_filter(:name, :eq, "Alice"))
    )

    assert_equal [], result
  end

  def test_default_queryable_none_can_be_overridden_with_all_queryable
    table = Prato.table(User) do
      configure(default_queryable: :none)
      column(:name, queryable: :all)
    end

    result = table.full(
      User.order(:id),
      query_params(filters: query_filter(:name, :eq, "Alice"))
    )

    assert_equal ["Alice"], result.map { |entry| entry[:name] }
    assert_equal 1, result.length
  end

  def test_none_queryable_column_can_display_but_not_filter_or_sort
    table = Prato.table(User) do
      column(:name, queryable: :none)
    end

    output = table.full(User.where(name: "Alice"))
    filtered = table.full(User.order(:id), query_params(filters: query_filter(:name, :eq, "Alice")))
    sorted = table.full(User.order(:id), query_params(sorts: [query_sort(:name, :asc)]))

    assert_equal "Alice", output.first[:name]
    assert_equal [], filtered
    assert_equal [], sorted
  end

  def test_default_queryable_can_be_overridden_with_all_queryable
    table = Prato.table(User) do
      configure(default_queryable: :none)
      column(:name, queryable: :all)
    end

    result = table.full(
      User.order(:id),
      query_params(filters: query_filter(:name, :eq, "Alice"))
    )

    assert_equal ["Alice"], result.map { |entry| entry[:name] }
    assert_equal 1, result.length
  end

  def test_display_only_column_with_filter_option_remains_filterable
    table = Prato.table(User) do
      column(:name, queryable: :none, filter: [:eq])
    end

    result = table.full(
      User.order(:id),
      query_params(filters: query_filter(:name, :eq, "Alice"))
    )

    assert_equal ["Alice"], result.map { |entry| entry[:name] }
    assert_equal 1, result.length
  end

  def test_default_queryable_none_can_be_overridden_with_filter_option
    table = Prato.table(User) do
      configure(default_queryable: :none)
      column(:name, filter: [:eq])
    end

    result = table.full(
      User.order(:id),
      query_params(filters: query_filter(:name, :eq, "Alice"))
    )

    assert_equal ["Alice"], result.map { |entry| entry[:name] }
    assert_equal 1, result.length
  end

  def test_filtering_on_display_only_column_raises_when_invalid_input_is_configured_to_raise
    table = Prato.table(User) do
      configure(on_invalid_input: :raise)
      column(:name, queryable: :none)
    end

    assert_raises(ArgumentError) do
      table.full(
        User.order(:id),
        query_params(filters: query_filter(:name, :eq, "Alice"))
      )
    end
  end

  def test_disallowed_filter_operator_raises_when_invalid_input_is_configured_to_raise
    table = Prato.table(User) do
      configure(on_invalid_input: :raise)
      column(:name, filter: [:eq])
    end

    assert_raises(ArgumentError) do
      table.full(
        User.order(:id),
        query_params(filters: query_filter(:name, :contains, "Ali"))
      )
    end
  end
end

class TestApiDefaultRubyColumnQueryable < Minitest::Test
  def test_default_ruby_column_queryable_none_displays_but_does_not_filter_or_sort
    table = Prato.table(User) do
      configure(default_ruby_column_queryable: :none)
      column(:name)
      ruby_column(:name_upcase, key: :id) do |records, _cache|
        index_records_by_id(records) { |user| user.name.upcase }
      end
    end

    output = table.full(User.where(name: "Alice"))
    filtered = table.full(User.order(:id), query_params(filters: query_filter(:name_upcase, :eq, "ALICE")))
    sorted = table.full(User.order(:id), query_params(sorts: [query_sort(:name_upcase, :desc)]))

    assert_equal "ALICE", output.first[:nameUpcase]
    assert_equal [], filtered
    assert_equal [], sorted
  end

  def test_ruby_column_all_queryable_overrides_default_ruby_column_queryable
    table = Prato.table(User) do
      configure(default_ruby_column_queryable: :none)
      column(:name)
      ruby_column(:post_count, key: :id, queryable: :all) do |records, _cache|
        counts = Post.group(:user_id).count
        index_records_by_id(records) { |user| counts.fetch(user.id, 0) }
      end
    end

    filtered = table.full(User.order(:id), query_params(filters: query_filter(:post_count, :gt, 2)))
    sorted = table.full(User.order(:id), query_params(sorts: [query_sort(:post_count, :desc)]))

    assert_equal %w[Alice Carol], filtered.map { |entry| entry[:name] }
    assert_equal %w[Alice Carol Bob Dave], sorted.map { |entry| entry[:name] }
  end

  def test_default_ruby_column_queryable_none_can_be_overridden_with_all_queryable
    table = Prato.table(User) do
      configure(default_ruby_column_queryable: :none)
      column(:name)
      ruby_column(:post_count, key: :id, queryable: :all) do |records, _cache|
        counts = Post.group(:user_id).count
        index_records_by_id(records) { |user| counts.fetch(user.id, 0) }
      end
    end

    filtered = table.full(User.order(:id), query_params(filters: query_filter(:post_count, :gt, 2)))
    sorted = table.full(User.order(:id), query_params(sorts: [query_sort(:post_count, :desc)]))

    assert_equal %w[Alice Carol], filtered.map { |entry| entry[:name] }
    assert_equal %w[Alice Carol Bob Dave], sorted.map { |entry| entry[:name] }
  end

  def test_query_column_queryable_filter_does_not_sort
    table = Prato.table(Post) do
      column(:title)
      query_column(author_name: %i[user name], queryable: :filter)
    end

    filtered = table.full(
      Post.order(:id),
      query_params(filters: query_filter(:author_name, :eq, "Alice"))
    )
    sorted = table.full(Post.order(:id), query_params(sorts: [query_sort(:author_name, :asc)]))

    assert_equal ["Hello", "Draft", "Ruby tips", "More Ruby"], filtered.map { |entry| entry[:title] }
    assert_equal [], sorted
  end

  def test_query_column_rejects_none_queryable
    assert_raises(ArgumentError) do
      Prato.table(Post) do
        column(:title)
        query_column(:author_name, %i[user name], queryable: :none)
      end
    end
  end
end
