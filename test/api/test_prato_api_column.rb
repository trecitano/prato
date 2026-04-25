# frozen_string_literal: true

require "test_helper"

module TestPratoApiColumn
  def validate(table, key)
    scope = User.where(name: "Alice")
    output = table.full(scope)
    assert_equal "Alice", output[:entries].first[key]
  end

  def validate_with_result(table, key, result)
    scope = User.where(name: "Alice")
    output = table.full(scope)
    assert_equal result, output[:entries].first[key]
  end

  def validate_avg_result(table, key, result)
    scope = User.where(name: "Alice")
    output = table.full(scope)
    assert_in_delta result, output[:entries].first[key].to_f, 0.01
  end
end

class TestApiColumnSingleArgument < Minitest::Test
  include TestPratoApiColumn

  def test_single_argument
    table = Prato.table(User) do
      column(:name)
    end

    validate(table, :name)
  end

  def test_single_argument_format
    table = Prato.table(User) do
      column(:name, format: lambda(&:upcase))
    end

    validate_with_result(table, :name, "ALICE")
  end

  def test_single_argument_format_only_display
    table = Prato.table(User) do
      column(:name, format: lambda(&:upcase), only: :display)
    end

    validate_with_result(table, :name, "ALICE")
  end

  def test_single_argument_format_only_filter
    table = Prato.table(User) do
      column(:name, format: lambda(&:upcase), only: :filter)
    end

    validate_with_result(table, :name, "ALICE")
  end

  def test_single_argument_format_only_sort
    table = Prato.table(User) do
      column(:name, format: lambda(&:upcase), only: :sort)
    end

    validate_with_result(table, :name, "ALICE")
  end
end

class TestApiColumnLabelAndAccessor < Minitest::Test
  include TestPratoApiColumn

  def test_two_arguments_symbol
    table = Prato.table(User) do
      column(:name, :name)
    end

    validate(table, :name)
  end

  def test_two_arguments_different_name_symbol
    table = Prato.table(User) do
      column(:specific_name, :name)
    end

    validate(table, :specificName)
  end

  def test_two_arguments_different_name_string
    table = Prato.table(User) do
      column("Specific Name", :name)
    end

    validate(table, :"Specific Name")
  end

  def test_two_arguments_format
    table = Prato.table(User) do
      column("Specific Name", :name, format: lambda(&:upcase))
    end

    validate_with_result(table, :"Specific Name", "ALICE")
  end

  def test_two_arguments_only_display
    table = Prato.table(User) do
      column(:specific_name, :name, only: :display)
    end

    validate(table, :specificName)
  end

  def test_two_arguments_only_filter
    table = Prato.table(User) do
      column(:specific_name, :name, only: :filter)
    end

    validate(table, :specificName)
  end

  def test_two_arguments_only_sort
    table = Prato.table(User) do
      column(:specific_name, :name, only: :sort)
    end

    validate(table, :specificName)
  end
end

class TestApiColumnExpression < Minitest::Test
  include TestPratoApiColumn

  def test_expression_basic_symbol
    table = Prato.table(User) do
      column(:double_age, expression: "users.age * 2")
    end

    validate_with_result(table, :doubleAge, 60)
  end

  def test_expression_basic_string
    table = Prato.table(User) do
      column("Double age!", expression: "users.age * 2")
    end

    validate_with_result(table, :"Double age!", 60)
  end

  def test_expression_format
    table = Prato.table(User) do
      column(:double_age, expression: "users.age * 2", format: ->(value) { value * 10 })
    end

    validate_with_result(table, :doubleAge, 600)
  end

  def test_expression_only_display
    table = Prato.table(User) do
      column(:double_age, expression: "users.age * 2", only: :display)
    end

    validate_with_result(table, :doubleAge, 60)
  end

  def test_expression_only_filter
    table = Prato.table(User) do
      column(:double_age, expression: "users.age * 2", only: :filter)
    end

    validate_with_result(table, :doubleAge, 60)
  end

  def test_expression_only_sort
    table = Prato.table(User) do
      column(:double_age, expression: "users.age * 2", only: :sort)
    end

    validate_with_result(table, :doubleAge, 60)
  end

  def test_expression_format_and_only_with_symbol
    table = Prato.table(User) do
      column(:double_age, expression: "users.age * 2", format: ->(value) { value * 10 }, only: :filter)
    end

    validate_with_result(table, :doubleAge, 600)
  end

  def test_expression_format_and_only_with_string
    table = Prato.table(User) do
      column("Double age!", expression: "users.age * 2", format: ->(value) { value * 10 }, only: :filter)
    end

    validate_with_result(table, :"Double age!", 600)
  end

  def test_expression_sql_function
    table = Prato.table(User) do
      column(:upper_name, expression: "UPPER(users.name)")
    end

    validate_with_result(table, :upperName, "ALICE")
  end

  def test_expression_model_sql_method
    table = Prato.table(User) do
      column(:latest_post, expression: :latest_post_summary_sql)
    end

    validate_with_result(table, :latestPost, "More Ruby")
  end

  def test_expression_model_sql_method_with_args
    table = Prato.table(User) do
      column(:high_score_posts, expression: User.post_count_above_sql(3))
    end

    validate_with_result(table, :highScorePosts, 3)
  end
end

class TestApiColumnCount < Minitest::Test
  include TestPratoApiColumn

  def test_count_basic_symbol
    table = Prato.table(User) do
      column(:post_count, count: :posts)
    end

    validate_with_result(table, :postCount, 4)
  end

  def test_count_basic_string
    table = Prato.table(User) do
      column("Super count!", count: :posts)
    end

    validate_with_result(table, :"Super count!", 4)
  end

  def test_count_format
    table = Prato.table(User) do
      column(:post_count, count: :posts, format: ->(value) { value * 10 })
    end

    validate_with_result(table, :postCount, 40)
  end

  def test_count_only_display
    table = Prato.table(User) do
      column(:post_count, count: :posts, only: :display)
    end

    validate_with_result(table, :postCount, 4)
  end

  def test_count_only_filter
    table = Prato.table(User) do
      column(:post_count, count: :posts, only: :filter)
    end

    validate_with_result(table, :postCount, 4)
  end

  def test_count_only_sort
    table = Prato.table(User) do
      column(:post_count, count: :posts, only: :sort)
    end

    validate_with_result(table, :postCount, 4)
  end

  def test_count_format_and_only_with_symbol
    table = Prato.table(User) do
      column(:post_count, count: :posts, format: ->(value) { value * 10 }, only: :filter)
    end

    validate_with_result(table, :postCount, 40)
  end

  def test_count_format_and_only_with_string
    table = Prato.table(User) do
      column("Super count!", count: :posts, format: ->(value) { value * 10 }, only: :filter)
    end

    validate_with_result(table, :"Super count!", 40)
  end

  def test_count_deep_association
    table = Prato.table(Company) do
      column(:comment_count, count: [:users, :posts, :comments])
    end

    scope = Company.where(name: "Acme Corp")
    output = table.full(scope)
    assert_equal 16, output[:entries].first[:commentCount]
  end
end

class TestApiColumnSum < Minitest::Test
  include TestPratoApiColumn

  def test_sum_basic_symbol
    table = Prato.table(User) do
      column(:post_score, sum: %i[posts score])
    end

    validate_with_result(table, :postScore, 14)
  end

  def test_sum_basic_string
    table = Prato.table(User) do
      column("Post score.", sum: %i[posts score])
    end

    validate_with_result(table, :"Post score.", 14)
  end

  def test_sum_format
    table = Prato.table(User) do
      column(:post_score, sum: %i[posts score], format: ->(value) { value * 20 })
    end

    validate_with_result(table, :postScore, 280)
  end

  def test_sum_only_display
    table = Prato.table(User) do
      column(:post_score, sum: %i[posts score], only: :display)
    end

    validate_with_result(table, :postScore, 14)
  end

  def test_sum_only_filter
    table = Prato.table(User) do
      column(:post_score, sum: %i[posts score], only: :filter)
    end

    validate_with_result(table, :postScore, 14)
  end

  def test_sum_only_sort
    table = Prato.table(User) do
      column(:post_score, sum: %i[posts score], only: :sort)
    end

    validate_with_result(table, :postScore, 14)
  end

  def test_sum_format_and_only_with_symbol
    table = Prato.table(User) do
      column(:post_score, sum: %i[posts score], format: ->(value) { value * 20 }, only: :filter)
    end

    validate_with_result(table, :postScore, 280)
  end

  def test_sum_format_and_only_with_string
    table = Prato.table(User) do
      column("Post score.", sum: %i[posts score], format: ->(value) { value * 20 }, only: :filter)
    end

    validate_with_result(table, :"Post score.", 280)
  end

  def test_sum_deep_association
    table = Prato.table(Company) do
      column(:sum_comment_score, sum: [:users, :posts, :comments, :score])
    end

    scope = Company.where(name: "Acme Corp")
    output = table.full(scope)
    assert_equal 48, output[:entries].first[:sumCommentScore]
  end
end

class TestApiColumnAvg < Minitest::Test
  include TestPratoApiColumn

  def test_avg_basic_symbol
    table = Prato.table(User) do
      column(:avg_post_score, avg: %i[posts score])
    end

    validate_avg_result(table, :avgPostScore, 3.5)
  end

  def test_avg_basic_string
    table = Prato.table(User) do
      column("Avg score.", avg: %i[posts score])
    end

    validate_avg_result(table, :"Avg score.", 3.5)
  end

  def test_avg_format
    table = Prato.table(User) do
      column(:avg_post_score, avg: %i[posts score], format: ->(value) { value * 20 })
    end

    validate_avg_result(table, :avgPostScore, 70)
  end

  def test_avg_only_display
    table = Prato.table(User) do
      column(:avg_post_score, avg: %i[posts score], only: :display)
    end

    validate_avg_result(table, :avgPostScore, 3.5)
  end

  def test_avg_only_filter
    table = Prato.table(User) do
      column(:avg_post_score, avg: %i[posts score], only: :filter)
    end

    validate_avg_result(table, :avgPostScore, 3.5)
  end

  def test_avg_only_sort
    table = Prato.table(User) do
      column(:avg_post_score, avg: %i[posts score], only: :sort)
    end

    validate_avg_result(table, :avgPostScore, 3.5)
  end

  def test_avg_format_and_only_with_symbol
    table = Prato.table(User) do
      column(:avg_post_score, avg: %i[posts score], format: ->(value) { value * 20 }, only: :filter)
    end

    validate_avg_result(table, :avgPostScore, 70)
  end

  def test_avg_format_and_only_with_string
    table = Prato.table(User) do
      column("Avg score.", avg: %i[posts score], format: ->(value) { value * 20 }, only: :filter)
    end

    validate_avg_result(table, :"Avg score.", 70)
  end

  def test_avg_deep_association
    table = Prato.table(Company) do
      column(:avg_comment_score, avg: [:users, :posts, :comments, :score])
    end

    scope = Company.where(name: "Acme Corp")
    output = table.full(scope)
    assert_in_delta 3.0, output[:entries].first[:avgCommentScore].to_f, 0.01
  end
end

class TestApiColumnMin < Minitest::Test
  include TestPratoApiColumn

  def test_min_basic_symbol
    table = Prato.table(User) do
      column(:min_post_score, min: %i[posts score])
    end

    validate_with_result(table, :minPostScore, 2)
  end

  def test_min_basic_string
    table = Prato.table(User) do
      column("Min score.", min: %i[posts score])
    end

    validate_with_result(table, :"Min score.", 2)
  end

  def test_min_format
    table = Prato.table(User) do
      column(:min_post_score, min: %i[posts score], format: ->(value) { value * 20 })
    end

    validate_with_result(table, :minPostScore, 40)
  end

  def test_min_only_display
    table = Prato.table(User) do
      column(:min_post_score, min: %i[posts score], only: :display)
    end

    validate_with_result(table, :minPostScore, 2)
  end

  def test_min_only_filter
    table = Prato.table(User) do
      column(:min_post_score, min: %i[posts score], only: :filter)
    end

    validate_with_result(table, :minPostScore, 2)
  end

  def test_min_only_sort
    table = Prato.table(User) do
      column(:min_post_score, min: %i[posts score], only: :sort)
    end

    validate_with_result(table, :minPostScore, 2)
  end

  def test_min_format_and_only_with_symbol
    table = Prato.table(User) do
      column(:min_post_score, min: %i[posts score], format: ->(value) { value * 20 }, only: :filter)
    end

    validate_with_result(table, :minPostScore, 40)
  end

  def test_min_format_and_only_with_string
    table = Prato.table(User) do
      column("Min score.", min: %i[posts score], format: ->(value) { value * 20 }, only: :filter)
    end

    validate_with_result(table, :"Min score.", 40)
  end

  def test_min_deep_association
    table = Prato.table(Company) do
      column(:min_comment_score, min: [:users, :posts, :comments, :score])
    end

    scope = Company.where(name: "Acme Corp")
    output = table.full(scope)
    assert_equal 1, output[:entries].first[:minCommentScore]
  end
end

class TestApiColumnMax < Minitest::Test
  include TestPratoApiColumn

  def test_max_basic_symbol
    table = Prato.table(User) do
      column(:max_post_score, max: %i[posts score])
    end

    validate_with_result(table, :maxPostScore, 5)
  end

  def test_max_basic_string
    table = Prato.table(User) do
      column("Max score.", max: %i[posts score])
    end

    validate_with_result(table, :"Max score.", 5)
  end

  def test_max_format
    table = Prato.table(User) do
      column(:max_post_score, max: %i[posts score], format: ->(value) { value * 20 })
    end

    validate_with_result(table, :maxPostScore, 100)
  end

  def test_max_only_display
    table = Prato.table(User) do
      column(:max_post_score, max: %i[posts score], only: :display)
    end

    validate_with_result(table, :maxPostScore, 5)
  end

  def test_max_only_filter
    table = Prato.table(User) do
      column(:max_post_score, max: %i[posts score], only: :filter)
    end

    validate_with_result(table, :maxPostScore, 5)
  end

  def test_max_only_sort
    table = Prato.table(User) do
      column(:max_post_score, max: %i[posts score], only: :sort)
    end

    validate_with_result(table, :maxPostScore, 5)
  end

  def test_max_format_and_only_with_symbol
    table = Prato.table(User) do
      column(:max_post_score, max: %i[posts score], format: ->(value) { value * 20 }, only: :filter)
    end

    validate_with_result(table, :maxPostScore, 100)
  end

  def test_max_format_and_only_with_string
    table = Prato.table(User) do
      column("Max score.", max: %i[posts score], format: ->(value) { value * 20 }, only: :filter)
    end

    validate_with_result(table, :"Max score.", 100)
  end

  def test_max_deep_association
    table = Prato.table(Company) do
      column(:max_comment_score, max: [:users, :posts, :comments, :score])
    end

    scope = Company.where(name: "Acme Corp")
    output = table.full(scope)
    assert_equal 5, output[:entries].first[:maxCommentScore]
  end
end

class TestApiColumnSingleArgumentHash < Minitest::Test
  include TestPratoApiColumn

  def test_hash_symbol
    table = Prato.table(User) do
      column(amazing_name: :name)
    end

    validate(table, :amazingName)
  end


  def test_hash_string
    table = Prato.table(User) do
      column("This is a string!" => :name)
    end

    validate(table, :"This is a string!")
  end

  def test_hash_format
    table = Prato.table(User) do
      column(amazing_name: :name, format: lambda(&:upcase))
    end

    validate_with_result(table, :amazingName, "ALICE")
  end


  def test_two_arguments_only_display
    table = Prato.table(User) do
      column(amazing_name: :name, format: lambda(&:upcase), only: :display)
    end

    validate_with_result(table, :amazingName, "ALICE")
  end

  def test_two_arguments_only_filter
    table = Prato.table(User) do
      column(amazing_name: :name, format: lambda(&:upcase), only: :filter)
    end

    validate_with_result(table, :amazingName, "ALICE")
  end

  def test_two_arguments_only_sort
    table = Prato.table(User) do
      column(amazing_name: :name, format: lambda(&:upcase), only: :sort)
    end

    validate_with_result(table, :amazingName, "ALICE")
  end
end

class TestApiColumnFilterOption < Minitest::Test
  def test_filter_rejects_invalid_option_type
    assert_raises(ArgumentError) do
      Prato.table(User) do
        column(:name, filter: Object.new)
      end
    end
  end

  def test_filter_rejects_invalid_array_entries
    assert_raises(ArgumentError) do
      Prato.table(User) do
        column(:name, filter: [:eq, 123])
      end
    end
  end

  def test_filter_rejects_string_operators
    assert_raises(ArgumentError) do
      Prato.table(User) do
        column(:name, filter: %w[eq contains])
      end
    end
  end
end

class TestApiColumnReservedKeywordNames < Minitest::Test
  include TestPratoApiColumn

  def test_column_named_format
    table = Prato.table(User) do
      column(:format, :name)
    end

    validate(table, :format)
  end

  def test_column_named_expression
    table = Prato.table(User) do
      column(:expression, :name)
    end

    validate(table, :expression)
  end

  def test_column_named_only
    table = Prato.table(User) do
      column(:only, :name)
    end

    validate(table, :only)
  end

  def test_column_named_count
    table = Prato.table(User) do
      column(:count, :name)
    end

    validate(table, :count)
  end

  def test_column_named_sum
    table = Prato.table(User) do
      column(:sum, :name)
    end

    validate(table, :sum)
  end

  def test_column_named_avg
    table = Prato.table(User) do
      column(:avg, :name)
    end

    validate(table, :avg)
  end

  def test_column_named_min
    table = Prato.table(User) do
      column(:min, :name)
    end

    validate(table, :min)
  end

  def test_column_named_max
    table = Prato.table(User) do
      column(:max, :name)
    end

    validate(table, :max)
  end

  def test_column_named_format_with_string
    table = Prato.table(User) do
      column("format", :name)
    end

    validate(table, :format)
  end

  def test_column_named_only_with_string
    table = Prato.table(User) do
      column("only", :name)
    end

    validate(table, :only)
  end
end
