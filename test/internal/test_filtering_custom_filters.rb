# frozen_string_literal: true

require "test_helper"

module FilteringCustomHelpers
  private

  def assert_names(result, expected_names)
    assert_equal expected_names.sort, result[:entries].map { |e| e[:name] }.sort
    assert_equal expected_names.length, result[:totalCount]
  end

  def assert_bodies(result, expected_bodies)
    assert_equal expected_bodies.sort, result[:entries].map { |e| e[:body] }.sort
    assert_equal expected_bodies.length, result[:totalCount]
  end

  def result_for(table, scope, filters)
    table.full(scope, query_params(filters: filters))
  end
end

class TestFilteringCustomDirectColumn < Minitest::Test
  include FilteringCustomHelpers

  def setup
    @table = Prato.table(User) do
      column(:name)
      column(:age, filter: lambda { |scope, operator, value|
        case operator
        when :eq
          scope.where(age: Array(value).map { |v| [v - 1, v, v + 1] }.flatten)
        end
      })

      configure(on_invalid_input: :raise)
    end
  end

  def test_custom_filter_overrides_eq
    result = result_for(@table, User.order(:id), query_filter(:age, :eq, 25))
    assert_names(result, ["Carol"])
  end

  def test_custom_filter_falls_back_to_default_for_other_operators
    result = result_for(@table, User.order(:id), query_filter(:age, :gt, 30))
    assert_names(result, ["Dave"])
  end

  def test_custom_filter_falls_back_for_between
    result = result_for(@table, User.order(:id), query_filter(:age, :between, [20, 30]))
    assert_names(result, %w[Alice Carol])
  end

  def test_non_custom_column_still_works
    result = result_for(@table, User.order(:id), query_filter(:name, :eq, "Alice"))
    assert_names(result, ["Alice"])
  end
end

class TestFilteringCustomAssociationColumn < Minitest::Test
  include FilteringCustomHelpers

  def setup
    @table = Prato.table(User) do
      column(:name)
      column(company_name: %i[company name], filter: lambda { |scope, operator, value|
        case operator
        when :eq
          scope.where(companies: { name: value, industry: "tech" })
        end
      })

      configure(on_invalid_input: :raise)
    end
  end

  def test_custom_filter_narrows_association_eq
    result = result_for(@table, User.order(:id), query_filter(:company_name, :eq, "Acme Corp"))
    assert_names(result, %w[Alice Bob])
  end

  def test_custom_filter_eq_excludes_non_tech_companies
    result = result_for(@table, User.order(:id), query_filter(:company_name, :eq, "Globex"))
    assert_names(result, [])
  end

  def test_custom_filter_falls_back_for_contains
    result = result_for(@table, User.order(:id), query_filter(:company_name, :contains, "Acme"))
    assert_names(result, %w[Alice Bob])
  end
end

class TestFilteringCustomExpressionColumn < Minitest::Test
  include FilteringCustomHelpers

  def setup
    @table = Prato.table(User) do
      column(:name)
      column(:age_doubled, expression: "users.age * 2", filter: lambda { |scope, operator, value|
        case operator
        when :gte
          scope.where("users.age * 2 >= ? AND users.active = ?", value, true)
        end
      })

      configure(on_invalid_input: :raise)
    end
  end

  def test_custom_filter_adds_extra_condition_on_gte
    result = result_for(@table, User.order(:id), query_filter(:age_doubled, :gte, 50))
    assert_names(result, %w[Alice Dave])
  end

  def test_custom_filter_falls_back_for_eq
    result = result_for(@table, User.order(:id), query_filter(:age_doubled, :eq, 60))
    assert_names(result, ["Alice"])
  end
end

class TestFilteringCustomAggregateColumn < Minitest::Test
  include FilteringCustomHelpers

  def setup
    @table = Prato.table(User) do
      column(:name)
      column(:post_count, count: :posts, filter: lambda { |scope, operator, value|
        case operator
        when :eq
          subquery = Post.where("posts.user_id = users.id").where(published: true).select("COUNT(*)")
          scope.where("(#{subquery.to_sql}) = ?", value)
        end
      })

      configure(on_invalid_input: :raise)
    end
  end

  def test_custom_filter_counts_only_published_posts
    result = result_for(@table, User.order(:id), query_filter(:post_count, :eq, 3))
    assert_names(result, ["Alice"])
  end

  def test_custom_filter_falls_back_for_gte
    result = result_for(@table, User.order(:id), query_filter(:post_count, :gte, 3))
    assert_names(result, %w[Alice Carol])
  end
end

class TestFilteringCustomRubyColumn < Minitest::Test
  include FilteringCustomHelpers

  def setup
    @table = Prato.table(User) do
      column(:name)
      ruby_column(:name_length, key: :id, filter: lambda { |actual, operator, value|
        case operator
        when :eq
          actual >= value - 1 && actual <= value + 1
        end
      })

      ruby_loader(:name_length) do |records, _cache|
        index_records_by_id(records) { |user| user.name.length }
      end

      configure(on_invalid_input: :raise)
    end
  end

  def test_custom_ruby_filter_overrides_eq_with_fuzzy_match
    result = result_for(@table, User.order(:id), query_filter(:name_length, :eq, 4))
    assert_names(result, %w[Alice Bob Carol Dave])
  end

  def test_custom_ruby_filter_falls_back_for_gt
    result = result_for(@table, User.order(:id), query_filter(:name_length, :gt, 4))
    assert_names(result, %w[Alice Carol])
  end
end

class TestFilteringCustomAndComposition < Minitest::Test
  include FilteringCustomHelpers

  def setup
    @table = Prato.table(User) do
      column(:name)
      column(:age, filter: lambda { |scope, operator, value|
        case operator
        when :gte
          scope.where("users.age >= ? AND users.active = ?", value, true)
        end
      })
      column(company_name: %i[company name])

      configure(on_invalid_input: :raise)
    end
  end

  def test_custom_filter_chains_with_normal_filter_in_and
    filters = query_and(
      query_filter(:age, :gte, 25),
      query_filter(:company_name, :eq, "Acme Corp")
    )

    result = result_for(@table, User.order(:id), filters)
    assert_names(result, ["Alice"])
  end

  def test_custom_filter_chains_with_another_normal_filter
    filters = query_and(
      query_filter(:age, :gte, 17),
      query_filter(:name, :contains, "o")
    )

    result = result_for(@table, User.order(:id), filters)
    assert_names(result, ["Bob"])
  end

  def test_custom_filter_fallback_works_in_and_composition
    filters = query_and(
      query_filter(:age, :lt, 30),
      query_filter(:name, :in, %w[Bob Carol])
    )

    result = result_for(@table, User.order(:id), filters)
    assert_names(result, %w[Bob Carol])
  end
end

class TestFilteringCustomOrComposition < Minitest::Test
  include FilteringCustomHelpers

  def setup
    @table = Prato.table(User) do
      column(:name)
      column(:age, filter: lambda { |scope, operator, value|
        case operator
        when :eq
          scope.where(age: [value - 1, value, value + 1])
        end
      })
      column(company_name: %i[company name])

      configure(on_invalid_input: :raise)
    end
  end

  def test_custom_filter_inside_or_with_normal_filter
    filters = query_or(
      query_filter(:age, :eq, 30),
      query_filter(:name, :eq, "Bob")
    )

    result = result_for(@table, User.order(:id), filters)
    assert_names(result, %w[Alice Bob])
  end

  def test_custom_filter_inside_nested_or
    filters = query_or(
      query_filter(:name, :eq, "Dave"),
      query_or(
        query_filter(:age, :eq, 18),
        query_filter(:company_name, :eq, "Globex")
      )
    )

    result = result_for(@table, User.order(:id), filters)
    assert_names(result, %w[Bob Carol Dave])
  end

  def test_custom_filter_fallback_inside_or
    filters = query_or(
      query_filter(:age, :gt, 35),
      query_filter(:name, :eq, "Bob")
    )

    result = result_for(@table, User.order(:id), filters)
    assert_names(result, %w[Bob Dave])
  end
end

class TestFilteringCustomMixedComposition < Minitest::Test
  include FilteringCustomHelpers

  def setup
    @table = Prato.table(Comment) do
      column(:body)
      column(:score, filter: lambda { |scope, operator, value|
        case operator
        when :gte
          scope.where("comments.score >= ? AND comments.score <= ?", value, value + 1)
        end
      })
      column(author_name: %i[user name])
      column(post_title: %i[post title])

      configure(on_invalid_input: :raise)
    end
  end

  def test_custom_filter_in_and_with_association
    filters = query_and(
      query_filter(:score, :gte, 4),
      query_filter(:author_name, :eq, "Alice")
    )

    result = result_for(@table, Comment.order(:id), filters)
    assert_bodies(result, ["Good advice", "Interesting take", "Rails is fun", "What about bonds?"])
  end

  def test_custom_filter_in_or_with_association
    filters = query_or(
      query_filter(:score, :gte, 5),
      query_filter(:post_title, :eq, "Hello")
    )

    result = result_for(@table, Comment.order(:id), filters)
    assert_bodies(result, [
                    "Agreed", "Bull market?", "Good advice", "Good luck",
                    "Great post!", "Thanks for sharing", "Really helpful"
                  ])
  end

  def test_custom_filter_in_nested_and_inside_or
    filters = query_or(
      query_and(
        query_filter(:score, :gte, 4),
        query_filter(:author_name, :eq, "Bob")
      ),
      query_filter(:post_title, :eq, "Learning Rails")
    )

    result = result_for(@table, Comment.order(:id), filters)
    assert_bodies(result, ["Bull market?", "Love gems", "Rails is fun", "Good luck"])
  end
end

class TestFilteringCustomWithRubyMixed < Minitest::Test
  include FilteringCustomHelpers

  def setup
    @table = Prato.table(User) do
      column(:name)
      column(:age, filter: lambda { |scope, operator, value|
        case operator
        when :eq
          scope.where(age: [value - 1, value, value + 1])
        end
      })

      ruby_column(:name_length, key: :id)

      ruby_loader(:name_length) do |records, _cache|
        index_records_by_id(records) { |user| user.name.length }
      end

      configure(on_invalid_input: :raise)
    end
  end

  def test_custom_sql_filter_chains_with_ruby_filter_in_and
    filters = query_and(
      query_filter(:age, :eq, 25),
      query_filter(:name_length, :gte, 5)
    )

    result = result_for(@table, User.order(:id), filters)
    assert_names(result, ["Carol"])
  end

  def test_custom_sql_filter_in_or_demoted_to_ruby_with_ruby_column
    skip "This is a weird scenario. Will ignore it for now."

    filters = query_or(
      query_filter(:age, :eq, 40),
      query_filter(:name_length, :eq, 3)
    )

    result = result_for(@table, User.order(:id), filters)
    assert_names(result, %w[Bob Dave])
  end
end

class TestFilteringCustomSectionColumn < Minitest::Test
  include FilteringCustomHelpers

  def setup
    @table = Prato.table(User) do
      column(:name)

      section(:profile) do
        column(:age, filter: lambda { |scope, operator, value|
          case operator
          when :eq
            scope.where(age: [value - 1, value, value + 1])
          end
        })
      end

      configure(on_invalid_input: :raise)
    end
  end

  def test_custom_filter_works_on_sectioned_column
    result = result_for(@table, User.order(:id), query_filter(%i[profile age], :eq, 25))
    assert_names(result, ["Carol"])
  end

  def test_custom_filter_fallback_works_on_sectioned_column
    result = result_for(@table, User.order(:id), query_filter(%i[profile age], :gt, 30))
    assert_names(result, ["Dave"])
  end
end

class TestFilteringCustomDefaultFallback < Minitest::Test
  include FilteringCustomHelpers

  def setup
    @table = Prato.table(User) do
      column(:name, filter: lambda { |_scope, _operator, _value|
        nil
      })

      configure(on_invalid_input: :raise)
    end
  end

  def test_always_default_filter_behaves_like_no_custom_filter
    result = result_for(@table, User.order(:id), query_filter(:name, :eq, "Alice"))
    assert_names(result, ["Alice"])
  end

  def test_always_default_filter_works_with_contains
    result = result_for(@table, User.order(:id), query_filter(:name, :contains, "ob"))
    assert_names(result, ["Bob"])
  end

  def test_always_default_filter_works_with_in
    result = result_for(@table, User.order(:id), query_filter(:name, :in, %w[Alice Dave]))
    assert_names(result, %w[Alice Dave])
  end
end
