# frozen_string_literal: true

require "test_helper"

class TestApiQueryColumnFiltering < Minitest::Test
  def test_query_column_can_filter_without_serializing_query_only_field
    table = Prato.table(Post) do
      column(:title)
      query_column(author_name: %i[user name])
    end

    result = table.to_table(
      Post.order(:id),
      params: query_params(filters: query_filter(:author_name, :eq, "Alice"))
    )

    assert_equal(["Hello", "Draft", "Ruby tips", "More Ruby"], result[:entries].map { |entry| entry[:title] })
    assert(result[:entries].all? { |entry| entry.keys == [:title] })
  end

  def test_query_column_has_many_filters_duplicates_rows_or_total_count
    table = Prato.table(Post) do
      column(:title)
      query_column(tag_name: %i[tags name])
    end

    result = table.to_page(
      Post.order(:id),
      params: query_params(page: 1, per_page: 10, filters: query_filter(:tag_name, :in, %w[rails ruby]))
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

    result = table.to_page(
      Post.order(:id),
      params: query_params(
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

    result = table.to_table(
      Post.order(:id),
      params: query_params(filters: query_filter(:author_name, :icontains, "ALI"))
    )

    assert_equal(["Hello", "Draft", "Ruby tips", "More Ruby"], result[:entries].map { |entry| entry[:title] })
  end

  def test_query_column_array_filter_allowlist_rejects_other_operators
    table = Prato.table(Post) do
      column(:title)
      query_column(author_name: %i[user name], filter: %i[eq])
    end

    result = table.to_table(
      Post.order(:id),
      params: query_params(filters: query_filter(:author_name, :contains, "Ali"))
    )

    assert_equal [], result[:entries]
    assert_equal 0, result[:totalCount]
  end
end

class TestApiDisplayOnlyColumnFiltering < Minitest::Test
  def test_filtering_on_display_only_column_returns_empty_result_by_default
    table = Prato.table(User) do
      column(:name, only: :display)
    end

    result = table.to_table(
      User.order(:id),
      params: query_params(filters: query_filter(:name, :eq, "Alice"))
    )

    assert_equal [], result[:entries]
    assert_equal 0, result[:totalCount]
  end

  def test_display_only_column_with_filter_option_remains_filterable
    table = Prato.table(User) do
      column(:name, only: :display, filter: [:eq])
    end

    result = table.to_table(
      User.order(:id),
      params: query_params(filters: query_filter(:name, :eq, "Alice"))
    )

    assert_equal ["Alice"], result[:entries].map { |entry| entry[:name] }
    assert_equal 1, result[:totalCount]
  end

  def test_display_default_only_can_be_overridden_with_filter_option
    table = Prato.table(User) do
      configure(default_only: :display)
      column(:name, filter: [:eq])
    end

    result = table.to_table(
      User.order(:id),
      params: query_params(filters: query_filter(:name, :eq, "Alice"))
    )

    assert_equal ["Alice"], result[:entries].map { |entry| entry[:name] }
    assert_equal 1, result[:totalCount]
  end

  def test_filtering_on_display_only_column_raises_when_invalid_input_is_configured_to_raise
    table = Prato.table(User) do
      configure(on_invalid_input: :raise)
      column(:name, only: :display)
    end

    assert_raises(ArgumentError) do
      table.to_table(
        User.order(:id),
        params: query_params(filters: query_filter(:name, :eq, "Alice"))
      )
    end
  end

  def test_disallowed_filter_operator_raises_when_invalid_input_is_configured_to_raise
    table = Prato.table(User) do
      configure(on_invalid_input: :raise)
      column(:name, filter: [:eq])
    end

    assert_raises(ArgumentError) do
      table.to_table(
        User.order(:id),
        params: query_params(filters: query_filter(:name, :contains, "Ali"))
      )
    end
  end
end
