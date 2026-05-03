# frozen_string_literal: true

require "test_helper"

module FilteringComplexAssertions
  private

  def comment_bodies(result)
    result.map { |entry| entry[:body] }.sort
  end

  def assert_comment_bodies(result, expected_bodies)
    assert_equal expected_bodies.sort, result.map { |entry| entry[:body] }.sort
    assert_equal expected_bodies.length, result.length
  end
end

module FilteringComplexHelpers
  private

  def build_comment_ruby_table
    Prato.table(Comment) do
      configure(default_ruby_column_queryable: :all, on_invalid_input: :raise)
      column(:body)
      ruby_column(:body_length, key: :id)
      ruby_column(:body_upcase, key: :id)
      ruby_column(:body_starts_with_g, key: :id)
      ruby_column(:commenter_company, key: :id, includes: { user: :company })
      ruby_column(:post_author_company, key: :id, includes: { post: { user: :company } })
      ruby_column(:category_name_ruby, key: :id, includes: { post: :category })
      ruby_column(:parent_category_name_ruby, key: :id, includes: { post: { category: :parent_category } })

      ruby_loader(:body_map) do |records, _cache|
        index_records_by_id(records, &:body)
      end

      ruby_loader(:category_map) do |records, _cache|
        index_records_by_id(records) { |comment| comment.post.category }
      end

      ruby_loader(:commenter_company_map) do |records, _cache|
        index_records_by_id(records) { |comment| comment.user.company&.name }
      end

      ruby_loader(:post_author_company_map) do |records, _cache|
        index_records_by_id(records) { |comment| comment.post.user.company&.name }
      end

      ruby_loader(:parent_category_map) do |_records, cache|
        transform_hash_values(cache[:category_map]) { |category| category&.parent_category&.name }
      end

      ruby_loader(:category_name_map) do |_records, cache|
        transform_hash_values(cache[:category_map]) { |category| category&.name }
      end

      ruby_loader(:body_length_map) do |_records, cache|
        transform_hash_values(cache[:body_map], &:length)
      end

      ruby_loader(:body_upcase_map) do |_records, cache|
        transform_hash_values(cache[:body_map], &:upcase)
      end

      ruby_loader(:body_starts_with_g_map) do |_records, cache|
        transform_hash_values(cache[:body_map]) { |body| body.start_with?("G") ? body : nil }
      end

      ruby_loader(:body_length) do |_records, cache|
        cache[:body_length_map]
      end

      ruby_loader(:body_upcase) do |_records, cache|
        cache[:body_upcase_map]
      end

      ruby_loader(:body_starts_with_g) do |_records, cache|
        cache[:body_starts_with_g_map]
      end

      ruby_loader(:commenter_company) do |_records, cache|
        cache[:commenter_company_map]
      end

      ruby_loader(:post_author_company) do |_records, cache|
        cache[:post_author_company_map]
      end

      ruby_loader(:category_name_ruby) do |_records, cache|
        cache[:category_name_map]
      end

      ruby_loader(:parent_category_name_ruby) do |_records, cache|
        cache[:parent_category_map]
      end
    end
  end

  def build_comment_mixed_table
    Prato.table(Comment) do
      configure(default_ruby_column_queryable: :all, on_invalid_input: :raise)
      column(:body)
      column(:score)
      column(author_name: %i[user name])
      column(post_title: %i[post title])
      column(post_author_name: %i[post user name])
      column(post_category: %i[post category name])
      column(post_parent_category: %i[post category parent_category name])
      column(:score_filter_only, expression: "comments.score", queryable: :filter)
      column(:post_comment_count_filter_only, count: %i[post comments], queryable: :filter)
      ruby_column(:body_length, key: :id)
      ruby_column(:body_upcase, key: :id)
      ruby_column(:body_starts_with_g, key: :id)
      ruby_column(:commenter_company, key: :id)
      ruby_column(:post_author_company, key: :id)

      ruby_loader(:body_map) do |records, _cache|
        index_records_by_id(records, &:body)
      end

      ruby_loader(:body_length) do |_records, cache|
        transform_hash_values(cache[:body_map], &:length)
      end

      ruby_loader(:body_upcase) do |_records, cache|
        transform_hash_values(cache[:body_map], &:upcase)
      end

      ruby_loader(:body_starts_with_g) do |_records, cache|
        transform_hash_values(cache[:body_map]) { |body| body.start_with?("G") ? body : nil }
      end

      ruby_loader(:commenter_company, includes: { user: :company }) do |records, _cache|
        index_records_by_id(records) { |comment| comment.user.company&.name }
      end

      ruby_loader(:post_author_company, includes: { post: { user: :company } }) do |records, _cache|
        index_records_by_id(records) { |comment| comment.post.user.company&.name }
      end
    end
  end

  def build_comment_mixed_section_table
    Prato.table(Comment) do
      configure(default_ruby_column_queryable: :all, on_invalid_input: :raise)
      column(:body)
      column(:score)
      column(:score_filter_only, expression: "comments.score", queryable: :filter)
      column(:post_comment_count_filter_only, count: %i[post comments], queryable: :filter)

      section(:commenter) do
        column(name: %i[user name])
        column(company: %i[user company name])
      end

      section(:post_info) do
        column(title: %i[post title])

        section(:author) do
          column(name: %i[post user name])
          column(company: %i[post user company name])
        end

        section(:category) do
          column(name: %i[post category name])

          section(:parent) do
            column(name: %i[post category parent_category name])
          end
        end

        section(:stats) do
          column(:comment_count, count: %i[post comments])
        end
      end

      section(:computed) do
        ruby_column(:body_length, key: :id)
        ruby_column(:body_upcase, key: :id)
        ruby_column(:body_starts_with_g, key: :id)
        ruby_column(:commenter_company, key: :id)
        ruby_column(:post_author_company, key: :id)
      end

      ruby_loader(:body_map) do |records, _cache|
        index_records_by_id(records, &:body)
      end

      ruby_loader(:body_length) do |_records, cache|
        transform_hash_values(cache[:body_map], &:length)
      end

      ruby_loader(:body_upcase) do |_records, cache|
        transform_hash_values(cache[:body_map], &:upcase)
      end

      ruby_loader(:body_starts_with_g) do |_records, cache|
        transform_hash_values(cache[:body_map]) { |body| body.start_with?("G") ? body : nil }
      end

      ruby_loader(:commenter_company, includes: { user: :company }) do |records, _cache|
        index_records_by_id(records) { |comment| comment.user.company&.name }
      end

      ruby_loader(:post_author_company, includes: { post: { user: :company } }) do |records, _cache|
        index_records_by_id(records) { |comment| comment.post.user.company&.name }
      end
    end
  end

  def result_for(table, filters)
    table.full(Comment.order(:id), query_params(filters: filters))
  end

  def all_comment_bodies
    Comment.order(:id).pluck(:body)
  end

  def comments_without_parent_category_bodies
    [
      "Agreed",
      "Bull market?",
      "Good advice",
      "Good tip!",
      "I agree",
      "Interesting take",
      "Keep going!",
      "Nice start",
      "Saving now",
      "Thanks for the update",
      "Very useful",
      "Welcome!",
      "What about bonds?",
      "You got this"
    ]
  end
end

class TestFilteringEdgeCases < Minitest::Test
  include FilteringComplexAssertions
  include FilteringComplexHelpers

  def setup
    @table = Prato.table(Comment) do
      column(:body)
      column(:score)
      column(author_name: %i[user name])
      column(user_company_name: %i[user company name])
      column(post_title: %i[post title])
      column(post_author_name: %i[post user name])
      column(post_author_company_name: %i[post user company name])
      column(post_category: %i[post category name])
      column(post_parent_category: %i[post category parent_category name])
      column(:post_comment_count, count: %i[post comments])
      column(:score_doubled, expression: "comments.score * 2")

      configure(on_invalid_input: :raise)
    end
  end

  def test_duplicate_company_associations_can_be_filtered_independently
    filters = query_and(
      query_filter(:user_company_name, :eq, "Acme Corp"),
      query_filter(:post_author_company_name, :eq, "Acme Corp")
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Good tip!",
        "Great post!",
        "Love gems",
        "Puma is great",
        "Rails is fun",
        "Welcome!",
        "You got this"
      ]
    )
  end

  def test_self_referential_category_filters_do_not_cross_match_terminal_aliases
    filters = query_and(
      query_filter(:post_author_name, :eq, "Alice"),
      query_filter(:post_category, :eq, "Ruby"),
      query_filter(:post_parent_category, :eq, "Technology")
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Great post!",
        "Love gems",
        "Me too",
        "Puma is great",
        "Really helpful",
        "Thanks for sharing",
        "Which ones?"
      ]
    )
  end

  def test_comment_author_and_post_author_stay_distinct_inside_or_filters
    filters = query_or(
      query_filter(:author_name, :eq, "Alice"),
      query_filter(:post_author_name, :eq, "Alice")
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Good advice",
        "Good tip!",
        "Great post!",
        "I agree",
        "Interesting take",
        "Love gems",
        "Me too",
        "Puma is great",
        "Rails is fun",
        "Really helpful",
        "Thanks for sharing",
        "Welcome!",
        "What about bonds?",
        "Which ones?",
        "You got this"
      ]
    )
  end

  def test_optional_association_icontains_matches_ruby_mirror_columns
    ruby_table = build_comment_ruby_table
    expected_bodies = [
      "Good luck",
      "Great post!",
      "Love gems",
      "Me too",
      "Puma is great",
      "Rails is fun",
      "Really helpful",
      "Thanks for sharing",
      "Which ones?"
    ]

    sql_result = result_for(@table, query_filter(:post_parent_category, :icontains, "teCh"))
    ruby_result = result_for(ruby_table, query_filter(:parent_category_name_ruby, :icontains, "teCh"))

    assert_comment_bodies(sql_result, expected_bodies)
    assert_comment_bodies(ruby_result, expected_bodies)
  end

  def test_negated_optional_association_operators_match_ruby_mirror_columns
    ruby_table = build_comment_ruby_table

    {
      not_eq: "Technology",
      not_in: ["Technology"],
      not_contains: "Tech",
      not_icontains: "tech"
    }.each do |operator, value|
      sql_result = result_for(@table, query_filter(:post_parent_category, operator, value))
      ruby_result = result_for(ruby_table, query_filter(:parent_category_name_ruby, operator, value))

      assert_comment_bodies(sql_result, comments_without_parent_category_bodies)
      assert_comment_bodies(ruby_result, comments_without_parent_category_bodies)
    end
  end

  def test_simple_negative_optional_association_operators_include_nil_rows
    {
      not_eq: "Technology",
      not_in: ["Technology"],
      not_contains: "Tech",
      not_icontains: "teCh"
    }.each do |operator, value|
      assert_comment_bodies(
        result_for(@table, query_filter(:post_parent_category, operator, value)),
        comments_without_parent_category_bodies
      )
    end
  end

  def test_negative_optional_association_operators_with_nil_values_match_ruby_mirror_columns
    ruby_table = build_comment_ruby_table

    {
      not_eq: nil,
      not_in: [nil],
      not_contains: nil,
      not_icontains: nil
    }.each do |operator, value|
      sql_result = result_for(@table, query_filter(:post_parent_category, operator, value))
      ruby_result = result_for(ruby_table, query_filter(:parent_category_name_ruby, operator, value))

      assert_equal comment_bodies(ruby_result), comment_bodies(sql_result),
                   "expected #{operator.inspect} with #{value.inspect} to match ruby mirror semantics"
    end
  end
end

class TestFilteringComplexCases < Minitest::Test
  include FilteringComplexAssertions
  include FilteringComplexHelpers

  def setup
    @table = build_comment_mixed_section_table
  end

  def test_sectioned_fields_support_mixed_nested_filters
    filters = query_or(
      query_and(
        query_filter(%i[commenter name], :eq, "Alice"),
        query_filter(%i[post_info category parent name], :not_present, nil)
      ),
      query_and(
        query_filter(%i[post_info author name], :eq, "Alice"),
        query_filter(%i[computed body_length], :gte, 13)
      )
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Good advice",
        "Interesting take",
        "Puma is great",
        "Really helpful",
        "Thanks for sharing",
        "Welcome!",
        "What about bonds?",
        "You got this"
      ]
    )
  end

  def test_sectioned_filters_handle_duplicate_category_names_in_the_same_tree
    filters = query_and(
      query_filter(%i[commenter name], :in, %w[Bob Dave]),
      query_filter(%i[post_info category name], :eq, "Ruby"),
      query_filter(%i[post_info category parent name], :eq, "Technology")
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Good luck",
        "Great post!",
        "Love gems",
        "Puma is great",
        "Really helpful",
        "Which ones?"
      ]
    )
  end

  def test_invalid_operator_raises_when_invalid_input_is_configured_to_raise
    assert_raises(ArgumentError) do
      result_for(@table, query_filter(:score, :bogus, 3))
    end
  end
end

class TestFilteringSqlAndOperator < Minitest::Test
  include FilteringComplexAssertions
  include FilteringComplexHelpers

  def setup
    @table = Prato.table(Comment) do
      column(:body)
      column(:score)
      column(author_name: %i[user name])
      column(user_company_name: %i[user company name])
      column(post_title: %i[post title])
      column(post_author_name: %i[post user name])
      column(post_author_company_name: %i[post user company name])
      column(post_category: %i[post category name])
      column(post_parent_category: %i[post category parent_category name])
      column(:post_comment_count, count: %i[post comments])
      column(:score_doubled, expression: "comments.score * 2")

      configure(on_invalid_input: :raise)
    end
  end

  def test_deep_and_filter_handles_duplicate_association_targets
    filters = query_and(
      query_filter(:user_company_name, :eq, "Acme Corp"),
      query_and(
        query_filter(:post_author_company_name, :eq, "Acme Corp"),
        query_and(
          query_filter(:post_category, :eq, "Ruby"),
          query_filter(:post_parent_category, :eq, "Technology")
        )
      )
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Great post!",
        "Love gems",
        "Puma is great",
        "Rails is fun"
      ]
    )
  end

  def test_deep_and_filter_can_use_icontains_across_multiple_sql_associations
    filters = query_and(
      query_filter(:user_company_name, :eq, "Acme Corp"),
      query_and(
        query_filter(:post_author_company_name, :eq, "Acme Corp"),
        query_and(
          query_filter(:post_category, :icontains, "rub"),
          query_filter(:post_parent_category, :icontains, "teCh")
        )
      )
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Great post!",
        "Love gems",
        "Puma is great",
        "Rails is fun"
      ]
    )
  end

  def test_deep_and_filter_can_mix_sql_associations_aggregates_and_expressions
    filters = query_and(
      query_filter(:score_doubled, :gte, 8),
      query_and(
        query_filter(:post_comment_count, :gte, 4),
        query_and(
          query_filter(:post_author_name, :eq, "Bob"),
          query_filter(:post_category, :in, %w[Technology Ruby])
        )
      )
    )

    assert_comment_bodies(result_for(@table, filters), ["Agreed", "Keep going!"])
  end

  def test_and_filter_with_not_eq_nil_on_optional_association
    filters = query_and(
      query_filter(:post_parent_category, :not_eq, nil),
      query_filter(:author_name, :eq, "Bob")
    )

    assert_comment_bodies(
      result_for(@table, filters),
      ["Great post!", "Love gems", "Puma is great"]
    )
  end

  def test_and_filter_with_eq_nil_on_optional_association
    filters = query_and(
      query_filter(:post_parent_category, :eq, nil),
      query_filter(:author_name, :eq, "Alice")
    )

    assert_comment_bodies(
      result_for(@table, filters),
      ["Good advice", "Interesting take", "Welcome!", "What about bonds?", "You got this"]
    )
  end
end

class TestFilteringSqlOrOperator < Minitest::Test
  include FilteringComplexAssertions
  include FilteringComplexHelpers

  def setup
    @table = Prato.table(Comment) do
      column(:body)
      column(:score)
      column(author_name: %i[user name])
      column(user_company_name: %i[user company name])
      column(post_title: %i[post title])
      column(post_author_name: %i[post user name])
      column(post_author_company_name: %i[post user company name])
      column(post_category: %i[post category name])
      column(post_parent_category: %i[post category parent_category name])
      column(:post_comment_count, count: %i[post comments])
      column(:score_doubled, expression: "comments.score * 2")

      configure(on_invalid_input: :raise)
    end
  end

  def test_deep_or_filter_keeps_comment_and_post_author_paths_separate
    filters = query_or(
      query_filter(:post_author_name, :eq, "Carol"),
      query_or(
        query_filter(:author_name, :eq, "Dave"),
        query_filter(:post_title, :eq, "Hello")
      )
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Bull market?",
        "Good advice",
        "Good luck",
        "Great post!",
        "Interesting take",
        "Keep going!",
        "Really helpful",
        "Saving now",
        "Thanks for sharing",
        "Thanks for the update",
        "Very useful",
        "What about bonds?",
        "Which ones?"
      ]
    )
  end

  def test_deep_or_filter_can_mix_sql_associations_aggregates_and_expressions
    filters = query_or(
      query_filter(:score_doubled, :gte, 10),
      query_or(
        query_filter(:post_comment_count, :eq, 2),
        query_filter(:post_author_name, :eq, "Alice")
      )
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Agreed",
        "Bull market?",
        "Good advice",
        "Good luck",
        "Good tip!",
        "Great post!",
        "I agree",
        "Love gems",
        "Me too",
        "Puma is great",
        "Rails is fun",
        "Really helpful",
        "Thanks for sharing",
        "Which ones?"
      ]
    )
  end

  def test_deep_or_filter_keeps_nil_rows_when_not_present_branch_is_nested
    filters = query_or(
      query_filter(:post_parent_category, :eq, "Technology"),
      query_or(
        query_filter(:post_parent_category, :not_present, nil),
        query_filter(:post_title, :eq, "No such title")
      )
    )

    assert_comment_bodies(result_for(@table, filters), all_comment_bodies)
  end

  def test_or_filter_negative_optional_association_operators_still_include_nil_rows
    {
      not_eq: "Technology",
      not_in: ["Technology"],
      not_contains: "Tech"
    }.each do |operator, value|
      filters = query_or(
        query_filter(:post_parent_category, operator, value),
        query_filter(:post_title, :eq, "No such title")
      )

      assert_comment_bodies(result_for(@table, filters), comments_without_parent_category_bodies)
    end
  end

  def test_or_filter_with_not_eq_nil_on_optional_association_matches_present_semantics
    filters = query_or(
      query_filter(:post_parent_category, :not_eq, nil),
      query_filter(:post_title, :eq, "No such title")
    )

    assert_comment_bodies(
      result_for(@table, filters),
      ["Good luck", "Great post!", "Love gems", "Me too", "Puma is great",
       "Rails is fun", "Really helpful", "Thanks for sharing", "Which ones?"]
    )
  end

  def test_or_filter_with_eq_nil_on_optional_association_matches_not_present_semantics
    filters = query_or(
      query_filter(:post_parent_category, :eq, nil),
      query_filter(:post_title, :eq, "No such title")
    )

    assert_comment_bodies(result_for(@table, filters), comments_without_parent_category_bodies)
  end
end

class TestFilteringRubyAndOperator < Minitest::Test
  include FilteringComplexAssertions
  include FilteringComplexHelpers

  def setup
    @table = build_comment_ruby_table
  end

  def test_deep_and_filter_handles_weird_associations_using_only_ruby_columns
    filters = query_and(
      query_filter(:commenter_company, :eq, "Acme Corp"),
      query_and(
        query_filter(:post_author_company, :eq, "Acme Corp"),
        query_and(
          query_filter(:category_name_ruby, :eq, "Ruby"),
          query_filter(:parent_category_name_ruby, :eq, "Technology")
        )
      )
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Great post!",
        "Love gems",
        "Puma is great",
        "Rails is fun"
      ]
    )
  end

  def test_deep_and_filter_can_stack_multiple_ruby_predicates
    filters = query_and(
      query_filter(:body_upcase, :contains, "GOOD"),
      query_and(
        query_filter(:body_length, :between, [9, 11]),
        query_and(
          query_filter(:category_name_ruby, :eq, "Technology"),
          query_filter(:parent_category_name_ruby, :not_present, nil)
        )
      )
    )

    assert_comment_bodies(result_for(@table, filters), ["Good tip!"])
  end

  def test_deep_and_filter_can_stack_multiple_ruby_predicates_with_icontains
    filters = query_and(
      query_filter(:body_upcase, :icontains, "good"),
      query_and(
        query_filter(:body_length, :between, [9, 11]),
        query_and(
          query_filter(:category_name_ruby, :eq, "Technology"),
          query_filter(:parent_category_name_ruby, :not_present, nil)
        )
      )
    )

    assert_comment_bodies(result_for(@table, filters), ["Good tip!"])
  end
end

class TestFilteringRubyOrOperator < Minitest::Test
  include FilteringComplexAssertions
  include FilteringComplexHelpers

  def setup
    @table = build_comment_ruby_table
  end

  def test_deep_or_filter_handles_nil_and_nested_association_ruby_columns
    filters = query_or(
      query_filter(:parent_category_name_ruby, :eq, "Technology"),
      query_or(
        query_filter(:commenter_company, :not_present, nil),
        query_filter(:body_upcase, :contains, "PUMA")
      )
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Good luck",
        "Great post!",
        "Keep going!",
        "Love gems",
        "Me too",
        "Puma is great",
        "Rails is fun",
        "Really helpful",
        "Saving now",
        "Thanks for sharing",
        "Thanks for the update",
        "Which ones?"
      ]
    )
  end

  def test_deep_or_filter_can_union_multiple_weird_ruby_branches
    filters = query_or(
      query_filter(:commenter_company, :eq, "Globex"),
      query_or(
        query_filter(:post_author_company, :eq, "Globex"),
        query_filter(:body_length, :eq, 6)
      )
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Agreed",
        "Bull market?",
        "Good advice",
        "I agree",
        "Interesting take",
        "Me too",
        "Nice start",
        "Saving now",
        "Thanks for sharing",
        "Thanks for the update",
        "Very useful",
        "What about bonds?"
      ]
    )
  end
end

class TestFilteringAll < Minitest::Test
  include FilteringComplexAssertions
  include FilteringComplexHelpers

  def setup
    @table = build_comment_mixed_table
  end

  def test_complex_filter_can_mix_sql_and_ruby_inside_nested_or_branches
    filters = query_or(
      query_and(
        query_filter(:post_parent_category, :eq, "Technology"),
        query_filter(:commenter_company, :eq, "Acme Corp"),
        query_filter(:body_upcase, :contains, "PUMA")
      ),
      query_and(
        query_filter(:post_author_name, :eq, "Carol"),
        query_or(
          query_filter(:body_length, :gte, 16),
          query_filter(:score, :eq, 5)
        )
      )
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Bull market?",
        "Good advice",
        "Interesting take",
        "Puma is great",
        "Thanks for the update",
        "What about bonds?"
      ]
    )
  end

  def test_complex_filter_can_mix_sql_and_ruby_inside_nested_and_branches
    filters = query_and(
      query_or(
        query_filter(:post_category, :eq, "General"),
        query_filter(:body_starts_with_g, :present, nil)
      ),
      query_or(
        query_filter(:author_name, :eq, "Alice"),
        query_filter(:commenter_company, :not_present, nil)
      ),
      query_filter(:body_length, :gte, 8)
    )

    assert_comment_bodies(
      result_for(@table, filters),
      [
        "Good advice",
        "Good luck",
        "Interesting take",
        "Saving now",
        "Thanks for the update",
        "What about bonds?"
      ]
    )
  end

  def test_complex_filter_can_use_filter_only_expression_columns_inside_mixed_or_filters
    filters = query_or(
      query_and(
        query_filter(:score_filter_only, :gte, 5),
        query_filter(:score, :gte, 5)
      ),
      query_and(
        query_filter(:body_upcase, :contains, "PUMA"),
        query_filter(:body_length, :gte, 12)
      )
    )

    assert_comment_bodies(
      result_for(@table, filters),
      ["Agreed", "Bull market?", "Good advice", "Good luck", "Puma is great"]
    )
  end

  def test_complex_filter_can_use_filter_only_aggregate_columns_inside_mixed_or_filters
    filters = query_or(
      query_and(
        query_filter(:post_comment_count_filter_only, :eq, 2),
        query_filter(:body_length, :gte, 9)
      ),
      query_and(
        query_filter(:body_starts_with_g, :present, nil),
        query_filter(:body_upcase, :contains, "GOOD")
      )
    )

    assert_comment_bodies(
      result_for(@table, filters),
      ["Good advice", "Good luck", "Good tip!", "Rails is fun"]
    )
  end

  def test_mixed_and_filter_preserves_contains_semantics_for_sql_columns
    pure_sql_result = result_for(@table, query_filter(:post_parent_category, :contains, "tech"))
    mixed_result = result_for(
      @table,
      query_and(
        query_filter(:post_parent_category, :contains, "tech"),
        query_filter(:body_length, :gte, 0)
      )
    )

    assert_equal comment_bodies(pure_sql_result), comment_bodies(mixed_result)
  end

  def test_mixed_and_filter_preserves_icontains_semantics_for_sql_columns
    pure_sql_result = result_for(@table, query_filter(:post_parent_category, :icontains, "teCh"))
    mixed_result = result_for(
      @table,
      query_and(
        query_filter(:post_parent_category, :icontains, "teCh"),
        query_filter(:body_length, :gte, 0)
      )
    )

    assert_equal comment_bodies(pure_sql_result), comment_bodies(mixed_result)
  end

  def test_mixed_and_filter_preserves_negative_nil_semantics_for_sql_columns
    pure_sql_result = result_for(@table, query_filter(:post_parent_category, :not_eq, nil))
    mixed_result = result_for(
      @table,
      query_and(
        query_filter(:post_parent_category, :not_eq, nil),
        query_filter(:body_length, :gte, 0)
      )
    )

    assert_equal comment_bodies(pure_sql_result), comment_bodies(mixed_result)
  end

  def test_mixed_and_filter_with_not_eq_nil_combined_with_ruby_column
    filters = query_and(
      query_filter(:post_parent_category, :not_eq, nil),
      query_filter(:body_length, :gte, 12)
    )

    assert_comment_bodies(
      result_for(@table, filters),
      ["Puma is great", "Rails is fun", "Really helpful", "Thanks for sharing"]
    )
  end

  def test_mixed_or_filter_with_eq_nil_combined_with_ruby_column
    filters = query_or(
      query_filter(:post_parent_category, :eq, nil),
      query_filter(:body_starts_with_g, :present, nil)
    )

    assert_comment_bodies(
      result_for(@table, filters),
      comments_without_parent_category_bodies + ["Good luck", "Great post!"]
    )
  end
end
