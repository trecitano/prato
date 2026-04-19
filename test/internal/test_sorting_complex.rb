# frozen_string_literal: true

require "test_helper"

module SortingComplexHelpers
  ALL_POST_TITLES = [
    "Draft",
    "Finance tips",
    "Hello",
    "Learning Rails",
    "Market update",
    "More Ruby",
    "Ruby tips",
    "Unpublished",
    "Young dev"
  ].freeze

  private

  def names_for(table, scope: User.all, params: nil)
    table.to_table(scope, params: params)[:entries].map { |entry| entry[:name] }
  end

  def titles_for(table, scope: Post.all, params: nil, paginated: false)
    result = if paginated
               table.to_page(scope, params: params)
             else
               table.to_table(scope, params: params)
             end

    [result[:entries].map { |entry| entry[:title] }, result]
  end

  def company_name_loader
    lambda do |records, _cache|
      index_records_by_id(records) { |user| user.company&.name }
    end
  end

  def post_count_loader
    lambda do |records, _cache|
      counts = Post.group(:user_id).count
      index_records_by_id(records) { |user| counts.fetch(user.id, 0) }
    end
  end
end

class TestSortingAfterRubyFiltering < Minitest::Test
  include SortingComplexHelpers

  def test_direct_sort_after_ruby_filter_sorts_filtered_records
    company_name_loader_proc = company_name_loader

    table = Prato.table(User) do
      column(:name)
      column(:age)
      ruby_column(:company_name, key: :id, includes: :company, &company_name_loader_proc)
    end

    assert_equal(
      %w[Alice Carol Bob],
      names_for(
        table,
        params: {
          filters: query_filter(:company_name, :present, nil),
          sorts: query_sort(:age, :desc)
        }
      )
    )
  end

  def test_association_sort_after_ruby_filter_sorts_filtered_records
    post_count_loader_proc = post_count_loader

    table = Prato.table(User) do
      column(:name)
      column(company_name: %i[company name])
      ruby_column(:post_count, key: :id, &post_count_loader_proc)
    end

    assert_equal(
      %w[Bob Alice Carol],
      names_for(
        table,
        params: query_params(
          filters: query_filter(:post_count, :gte, 2),
          sorts: [query_sort(:company_name, :asc), query_sort(:name, :desc)]
        )
      )
    )
  end

  def test_mixed_ruby_and_visible_sql_sorts_work_after_ruby_filter_materializes_records
    company_name_loader_proc = company_name_loader

    table = Prato.table(User) do
      column(:name)
      column(:age)
      ruby_column(:company_name, key: :id, includes: :company, &company_name_loader_proc)
    end

    assert_equal(
      %w[Bob Alice Carol],
      names_for(
        table,
        params: query_params(
          filters: query_filter(:company_name, :present, nil),
          sorts: [query_sort(:company_name, :asc), query_sort(:age, :asc)]
        )
      )
    )
  end

  def test_query_only_expression_sort_remains_available_after_ruby_filter_materializes_records
    company_name_loader_proc = company_name_loader

    table = Prato.table(User) do
      column(:name)
      query_column(:age_plus_ten, expression: "users.age + 10")
      ruby_column(:company_name, key: :id, includes: :company, &company_name_loader_proc)
    end

    result = table.to_table(
      User.all,
      params: query_params(
        filters: query_filter(:company_name, :present, nil),
        sorts: [query_sort(:age_plus_ten, :asc), query_sort(:company_name, :desc), query_sort(:name, :asc)]
      )
    )

    assert_equal(%w[Bob Carol Alice], result[:entries].map { |entry| entry[:name] })
    assert(result[:entries].all? { |entry| entry.keys == %i[name companyName] })
  end

  def test_query_only_aggregate_sort_remains_available_after_ruby_filter_materializes_records
    company_name_loader_proc = company_name_loader

    table = Prato.table(User) do
      column(:name)
      query_column(:post_count_sql, count: :posts)
      ruby_column(:company_name, key: :id, includes: :company, &company_name_loader_proc)
    end

    result = table.to_table(
      User.all,
      params: query_params(
        filters: query_filter(:company_name, :present, nil),
        sorts: [query_sort(:post_count_sql, :asc), query_sort(:company_name, :desc), query_sort(:name, :asc)]
      )
    )

    assert_equal(%w[Bob Carol Alice], result[:entries].map { |entry| entry[:name] })
    assert(result[:entries].all? { |entry| entry.keys == %i[name companyName] })
  end
end

class TestSortingComplexSections < Minitest::Test
  include SortingComplexHelpers

  def test_section_association_sort_after_ruby_filter_sorts_filtered_records
    post_count_loader_proc = post_count_loader

    table = Prato.table(User) do
      column(:name)

      section(:profile) do
        column(company_name: %i[company name])
      end

      section(:computed) do
        ruby_column(:post_count, key: :id, &post_count_loader_proc)
      end
    end

    assert_equal(
      %w[Bob Alice Carol],
      names_for(
        table,
        params: {
          filters: [{ field: "computed.postCount", operator: "gte", value: 2 }],
          sorts: [
            { field: "profile.companyName", order: "asc" },
            { field: "name", order: "desc" }
          ]
        }
      )
    )
  end

  def test_section_aggregate_sort_after_ruby_filter_sorts_filtered_records
    company_name_loader_proc = company_name_loader

    table = Prato.table(User) do
      column(:name)

      section(:stats) do
        column(:post_count, count: :posts)
      end

      section(:computed) do
        ruby_column(:company_name, key: :id, includes: :company, &company_name_loader_proc)
      end
    end

    assert_equal(
      %w[Bob Carol Alice],
      names_for(
        table,
        params: {
          filters: [{ field: "computed.companyName", operator: "present", value: nil }],
          sorts: [{ field: "stats.postCount", order: "asc" }]
        }
      )
    )
  end
end

class TestSortingHasManyQueryColumns < Minitest::Test
  include SortingComplexHelpers

  def test_sorting_by_has_many_query_column_duplicates_rows_and_total_count
    table = Prato.table(Post) do
      column(:title)
      query_column(tag_name: %i[tags name])
    end
    titles, result = titles_for(
      table,
      params: query_params(
        page: 1,
        per_page: 20,
        sorts: [query_sort(:tag_name, :asc), query_sort(:title, :asc)]
      ),
      paginated: true
    )
    assert_equal(
      ["Draft", "Finance tips", "Hello", "Hello", "Learning Rails", "Market update", "More Ruby", "Ruby tips",
       "Unpublished", "Young dev"],
      titles.sort
    )
    assert_equal 10, titles.length
    assert_equal 10, result[:totalCount]
  end
end
