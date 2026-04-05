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

  def filter(field, operator, value)
    Prato::Query::Filter.new(field, operator, value)
  end

  def sort(field, order = :asc)
    Prato::Query::Sort.new(field, order)
  end

  def params(filters: nil, sorts: nil, page: nil, per_page: nil)
    Prato::Query::Parameters.new(
      filters: filters,
      sorts: sorts,
      page: page,
      per_page: per_page
    )
  end

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
      ruby_column(:company_name, key: :id, &company_name_loader_proc)
    end

    assert_equal(
      %w[Alice Carol Bob],
      names_for(
        table,
        params: params(
          filters: filter(:company_name, :present, nil),
          sorts: [sort(:age, :desc)]
        )
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
        params: params(
          filters: filter(:post_count, :gte, 2),
          sorts: [sort(:company_name, :asc), sort(:name, :desc)]
        )
      )
    )
  end

  def test_mixed_ruby_and_visible_sql_sorts_work_after_ruby_filter_materializes_records
    company_name_loader_proc = company_name_loader

    table = Prato.table(User) do
      column(:name)
      column(:age)
      ruby_column(:company_name, key: :id, &company_name_loader_proc)
    end

    assert_equal(
      %w[Bob Alice Carol],
      names_for(
        table,
        params: params(
          filters: filter(:company_name, :present, nil),
          sorts: [sort(:company_name, :asc), sort(:age, :asc)]
        )
      )
    )
  end

  def test_query_only_expression_sort_remains_available_after_ruby_filter_materializes_records
    company_name_loader_proc = company_name_loader

    table = Prato.table(User) do
      column(:name)
      query_column(:age_plus_ten, expression: "users.age + 10")
      ruby_column(:company_name, key: :id, &company_name_loader_proc)
    end

    result = table.to_table(
      User.all,
      params: params(
        filters: filter(:company_name, :present, nil),
        sorts: [sort(:age_plus_ten, :asc), sort(:company_name, :desc), sort(:name, :asc)]
      )
    )

    assert_equal(%w[Bob Carol Alice], result[:entries].map { |entry| entry[:name] })
    assert(result[:entries].all? { |entry| entry.keys == [:name, :companyName] })
  end

  def test_query_only_aggregate_sort_remains_available_after_ruby_filter_materializes_records
    company_name_loader_proc = company_name_loader

    table = Prato.table(User) do
      column(:name)
      query_column(:post_count_sql, count: :posts)
      ruby_column(:company_name, key: :id, &company_name_loader_proc)
    end

    result = table.to_table(
      User.all,
      params: params(
        filters: filter(:company_name, :present, nil),
        sorts: [sort(:post_count_sql, :asc), sort(:company_name, :desc), sort(:name, :asc)]
      )
    )

    assert_equal(%w[Bob Carol Alice], result[:entries].map { |entry| entry[:name] })
    assert(result[:entries].all? { |entry| entry.keys == [:name, :companyName] })
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
          filters: [{ field: "computed.post_count", operator: "gte", value: 2 }],
          sorts: [
            { field: "profile.company_name", direction: "asc" },
            { field: "name", direction: "desc" }
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
        ruby_column(:company_name, key: :id, &company_name_loader_proc)
      end
    end

    assert_equal(
      %w[Bob Carol Alice],
      names_for(
        table,
        params: {
          filters: [{ field: "computed.company_name", operator: "present", value: nil }],
          sorts: [{ field: "stats.post_count", direction: "asc" }]
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
      params: params(
        page: 1,
        per_page: 20,
        sorts: [sort(:tag_name, :asc), sort(:title, :asc)]
      ),
      paginated: true
    )
    assert_equal(
      ["Draft", "Finance tips", "Hello", "Hello", "Learning Rails", "Market update", "More Ruby", "Ruby tips", "Unpublished", "Young dev"],
      titles.sort
    )
    assert_equal 10, titles.length
    assert_equal 10, result[:totalCount]
  end
end
