# frozen_string_literal: true

require "test_helper"

module TestFiltering
  def setup
    @table = Prato.table(Comment) do
      # Direct columns
      column(:body)
      column(:score)

      # 1-level deep associations
      column(post_title: %i[post title])
      column(author_name: %i[user name])

      # 2-levels deep associations
      column(post_author: %i[post user name])
      column(post_category: %i[post category name])

      # 3-levels deep associations
      column(post_author_company: %i[post user company name])
      column(post_parent_category: %i[post category parent_category name])

      # Expression column
      column(:score_doubled, expression: "comments.score * 2")

      # Query-only column
      query_column(:created_at)

      # Capability restrictions
      column(:score_display_only, expression: "comments.score", only: :display)
      column(:score_filter_only, expression: "comments.score", only: :filter)
      column(:score_sort_only, expression: "comments.score", only: :sort)

      # Aggregates
      column(:user_post_count, count: %i[user posts])
      column(:user_max_post_score, max: %i[user posts score])
      column(:user_min_post_score, min: %i[user posts score])
      column(:user_total_post_score, sum: %i[user posts score])
      column(:user_avg_post_score, avg: %i[user posts score])

      # Sections
      section(:post_info) do
        column(title: %i[post title])
        column(published: %i[post published])

        section(:category) do
          column(name: %i[post category name])

          section(:parent) do
            column(name: %i[post category parent_category name])
          end
        end
      end

      # Ruby columns that depend on :body_map indirectly
      ruby_column(:body_length, key: :id) do |records, cache|
        bodies = cache[:body_map]
        bodies.transform_values { |body| body.length }
      end

      ruby_column(:body_upcase, key: :id) do |records, cache|
        bodies = cache[:body_map]
        bodies.transform_values { |body| body.upcase }
      end

      # Ruby column with no indirect dependency (standalone)
      ruby_column(:score_label, key: :score) do |records, _cache|
        records.index_by(&:id).transform_values do |c|
          c.score >= 4 ? "high" : "low"
        end
      end

      # Intermediate ruby_loader — not referenced by any column directly,
      # but consumed by :body_length and :body_upcase loaders via the cache
      ruby_loader(:body_map) do |records, _cache|
        records.index_by(&:id).transform_values(&:body)
      end

      configure(on_invalid_input: :raise)
    end
  end
end

class TestFilteringOperators < Minitest::Test
  # --- :eq ---

  def test_filter_eq_string
    filter = Prato::Query::Filter.new(:name, :eq, "Alice")
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    assert_equal 1, result[:entries].length
    assert_equal "Alice", result[:entries].first[:name]
  end

  def test_filter_eq_integer
    filter = Prato::Query::Filter.new(:age, :eq, 30)
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    assert_equal 1, result[:entries].length
    assert_equal "Alice", result[:entries].first[:name]
  end

  def test_filter_eq_boolean
    filter = Prato::Query::Filter.new(:active, :eq, false)
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    assert_equal 1, result[:entries].length
    assert_equal "Carol", result[:entries].first[:name]
  end

  # --- :not_eq ---

  def test_filter_not_eq
    filter = Prato::Query::Filter.new(:name, :not_eq, "Alice")
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }
    refute_includes names, "Alice"
    assert_equal 3, names.length
  end

  # --- :lt / :lte / :gt / :gte ---

  def test_filter_lt
    filter = Prato::Query::Filter.new(:age, :lt, 25)
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }
    assert_equal ["Bob"], names
  end

  def test_filter_lte
    filter = Prato::Query::Filter.new(:age, :lte, 25)
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Bob Carol], names
  end

  def test_filter_gt
    filter = Prato::Query::Filter.new(:age, :gt, 30)
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }
    assert_equal ["Dave"], names
  end

  def test_filter_gte
    filter = Prato::Query::Filter.new(:age, :gte, 30)
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Alice Dave], names
  end

  # --- :present / :not_present ---

  def test_filter_present
    filter = Prato::Query::Filter.new(:companyName, :present, nil)
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Alice Bob Carol], names
  end

  def test_filter_not_present
    filter = Prato::Query::Filter.new(:companyName, :not_present, nil)
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }
    assert_equal ["Dave"], names
  end

  # --- :in / :not_in ---

  def test_filter_in
    filter = Prato::Query::Filter.new(:name, :in, %w[Alice Bob])
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Alice Bob], names
  end

  def test_filter_not_in
    filter = Prato::Query::Filter.new(:name, :not_in, %w[Alice Bob])
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Carol Dave], names
  end

  # --- :contains / :not_contains ---

  def test_filter_contains
    filter = Prato::Query::Filter.new(:email, :contains, "alice")
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    assert_equal 1, result[:entries].length
    assert_equal "Alice", result[:entries].first[:name]
  end

  def test_filter_not_contains
    filter = Prato::Query::Filter.new(:email, :not_contains, "alice")
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Bob Carol Dave], names
  end

  # --- :between / :not_between ---

  def test_filter_between
    filter = Prato::Query::Filter.new(:age, :between, [20, 35])
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Alice Carol], names
  end

  def test_filter_not_between
    filter = Prato::Query::Filter.new(:age, :not_between, [20, 35])
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Bob Dave], names
  end

  # --- :between_exclusive / :not_between_exclusive ---

  def test_filter_between_exclusive
    # age 30 should be excluded with exclusive bounds [30, 40]
    filter = Prato::Query::Filter.new(:age, :between_exclusive, [17, 40])
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Alice Carol], names
  end

  def test_filter_not_between_exclusive
    filter = Prato::Query::Filter.new(:age, :not_between_exclusive, [20, 35])
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Bob Dave], names
  end

  # --- Multiple filters (AND) ---

  def test_multiple_filters_applied_as_and
    filters = [
      Prato::Query::Filter.new(:active, :eq, true),
      Prato::Query::Filter.new(:age, :gt, 20)
    ]
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filters))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Alice Dave], names
  end

  # --- No matches ---

  def test_filter_no_matches
    filter = Prato::Query::Filter.new(:name, :eq, "Nonexistent")
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    assert_equal 0, result[:entries].length
    assert_equal 0, result[:totalCount]
  end
end

# =============================================================================
# Association Filtering Tests
# =============================================================================

class TestFilteringAssociations < Minitest::Test
  def test_filter_on_association_column
    table = Prato.table(User) do
      column(:name)
      column(company_name: %i[company name])
    end

    filter = Prato::Query::Filter.new(:companyName, :eq, "Acme Corp")
    result = table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Alice Bob], names
  end

  def test_filter_contains_on_association
    table = Prato.table(Post) do
      column(:title)
      column(author: %i[user name])
    end

    filter = Prato::Query::Filter.new(:author, :contains, "Ali")
    result = table.to_table(Post.all, params: Prato::Query::Parameters.new(filters: filter))

    assert(result[:entries].all? { |e| e[:author] == "Alice" })
    assert_equal 4, result[:entries].length
  end
end

class TestFilteringCommentAssociations < Minitest::Test
  include TestFiltering

  def test_filter_present_on_self_referential_association_returns_parent_category_value
    result = filtered_comment_association_result(:present, nil)

    assert_equal 9, result[:entries].length
    assert_equal(
      [%w[Ruby Technology]],
      result[:entries].map { |e| [e[:postCategory], e[:postParentCategory]] }.uniq
    )
  end

  def test_filter_not_present_on_self_referential_association_keeps_nil_parent_categories
    result = filtered_comment_association_result(:not_present, nil)

    assert_equal 14, result[:entries].length
    assert_equal(
      [["Technology", nil], ["General", nil]],
      result[:entries].map { |e| [e[:postCategory], e[:postParentCategory]] }.uniq
    )
  end

  def test_filter_eq_on_self_referential_association_does_not_match_child_category_name
    result = filtered_comment_association_result(:eq, "Ruby")

    assert_equal [], result[:entries]
  end

  private

  def filtered_comment_association_result(operator, value)
    params = Prato::Query::Parameters.new(
      filters: Prato::Query::Filter.new(:post_parent_category, operator, value),
      fields: %i[post_category post_parent_category]
    )

    @table.to_table(Comment.all, params: params)
  end
end

# =============================================================================
# Composite Filter Tests (AND/OR)
# =============================================================================

class TestFilteringComposite < Minitest::Test
  def setup
    @table = Prato.table(User) do
      column(:name)
      column(:age)
      column(:active)
    end
  end

  def test_or_filter
    or_filter = Prato::Query::OrFilter.new([
                                             Prato::Query::Filter.new(:name, :eq, "Alice"),
                                             Prato::Query::Filter.new(:name, :eq, "Bob")
                                           ])
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: or_filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Alice Bob], names
  end

  def test_and_filter
    and_filter = Prato::Query::AndFilter.new([
                                               Prato::Query::Filter.new(:active, :eq, true),
                                               Prato::Query::Filter.new(:age, :gte, 30)
                                             ])
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: and_filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Alice Dave], names
  end

  def test_nested_and_within_or
    filter = Prato::Query::OrFilter.new([
                                          Prato::Query::AndFilter.new([
                                                                        Prato::Query::Filter.new(:active, :eq, true),
                                                                        Prato::Query::Filter.new(:age, :lt, 20)
                                                                      ]),
                                          Prato::Query::Filter.new(:name, :eq, "Carol")
                                        ])
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Bob Carol], names
  end

  def test_nested_or_within_and
    filter = Prato::Query::AndFilter.new([
                                           Prato::Query::Filter.new(:active, :eq, true),
                                           Prato::Query::OrFilter.new([
                                                                        Prato::Query::Filter.new(:age, :lt, 20),
                                                                        Prato::Query::Filter.new(:age, :gt, 35)
                                                                      ])
                                         ])
    result = @table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Bob Dave], names
  end
end

# =============================================================================
# Aggregate Column Filtering Tests
# =============================================================================

class TestFilteringAggregates < Minitest::Test
  def test_filter_on_aggregate_count
    table = Prato.table(User) do
      column(:name)
      column(:post_count, count: :posts)
    end

    filter = Prato::Query::Filter.new(:post_count, :gt, 2)
    result = table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Alice Carol], names
  end

  def test_filter_on_aggregate_count_eq_zero
    table = Prato.table(User) do
      column(:name)
      column(:post_count, count: :posts)
    end

    filter = Prato::Query::Filter.new(:post_count, :eq, 0)
    result = table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }
    assert_equal ["Dave"], names
  end

  def test_filter_on_nested_aggregate
    table = Prato.table(User) do
      column(:name)
      column(:total_comments, count: %i[posts comments])
    end

    filter = Prato::Query::Filter.new(:total_comments, :gt, 5)
    result = table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filter))

    names = result[:entries].map { |e| e[:name] }.sort
    # Alice: 9 comments, Bob: 7 comments, Carol: 7 comments
    assert_includes names, "Alice"
  end

  def test_combined_filter_and_aggregate_filter
    table = Prato.table(User) do
      column(:name)
      column(:active)
      column(:post_count, count: :posts)
    end

    filters = [
      Prato::Query::Filter.new(:active, :eq, true),
      Prato::Query::Filter.new(:post_count, :gte, 2)
    ]
    result = table.to_table(User.all, params: Prato::Query::Parameters.new(filters: filters))

    names = result[:entries].map { |e| e[:name] }.sort
    assert_equal %w[Alice Bob], names
  end
end

class TestFilteringAssociationAliases < Minitest::Test
  def test_self_referential_association_selects_from_terminal_join_alias
    table = Prato.table(Comment) do
      column(post_category: [:post, :category, :name])
      column(post_parent_category: [:post, :category, :parent_category, :name])
      column(parent_category_id:   [:post, :category, :parent_category, :id])
      configure(on_invalid_input: :raise)
    end
    result = table.to_table(
      Comment.all,
      params: nil # Prato::Query::Parameters.new(fields: [:post_category, :post_parent_category])
    )
    assert_equal 9, result[:entries].count { |e| e[:postParentCategory] == "Technology" }
    assert_equal 14, result[:entries].count { |e| e[:postParentCategory].nil? }
  end
end