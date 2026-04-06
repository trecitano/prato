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
end
