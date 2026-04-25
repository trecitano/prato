# frozen_string_literal: true

require "test_helper"
module TestPratoApiRubyColumn
  def validate(table, key)
    result = table.full(Company.all)
    assert_equal(
      [
        { key => "tested" },
        { key => "tested" }
      ], result[:entries]
    )
  end
end


class TestApiRubyColumnSingleArgumentWithBlock < Minitest::Test
  include TestPratoApiRubyColumn

  def test_single_argument_symbol_with_block
    table = Prato.table(Company) do
      ruby_column(:output) do |records, _|
        records.map { |r| [r.id, "tested: #{r.id}"] }.to_h
      end
    end

    result = table.full(Company.all)
    assert_equal(
      [
        { output: "tested: 1" },
        { output: "tested: 2" }
      ], result[:entries]
    )
  end

  def test_single_argument_string_with_block
    table = Prato.table(Company) do
      ruby_column("Fabulous Output") do |records, _|
        records.map { |r| [r.id, "tested: #{r.id}"] }.to_h
      end
    end

    result = table.full(Company.all)
    assert_equal(
      [
        { "Fabulous Output": "tested: 1" },
        { "Fabulous Output": "tested: 2" }
      ], result[:entries]
    )
  end

  def test_single_argument_hash_symbol_symbol_with_block
    table = Prato.table(Company) do
      ruby_column(output_name: :loader_name) do |records, _|
        records.map { |r| [r.id, "tested: #{r.id}"] }.to_h
      end
    end

    result = table.full(Company.all)
    assert_equal(
      [
        { outputName: "tested: 1" },
        { outputName: "tested: 2" }
      ], result[:entries]
    )
  end

  def test_single_argument_hash_string_symbol_with_block
    table = Prato.table(Company) do
      ruby_column("The Output" => :output_name) do |records, _|
        records.map { |r| [r.id, "tested: #{r.id}"] }.to_h
      end
    end

    result = table.full(Company.all)
    assert_equal(
      [
        { "The Output": "tested: 1" },
        { "The Output": "tested: 2" }
      ], result[:entries]
    )
  end
end

class TestApiRubyColumnSingleArgumentWithLoader < Minitest::Test
  include TestPratoApiRubyColumn

  def test_single_argument_symbol_with_loader
    table = Prato.table(Company) do
      ruby_column(:output)
      ruby_loader(:output) do |records, _|
        records.map { |r| [r.id, "tested: #{r.id}"] }.to_h
      end
    end

    result = table.full(Company.all)
    assert_equal(
      [
        { output: "tested: 1" },
        { output: "tested: 2" }
      ], result[:entries]
    )
  end

  def test_single_argument_string_with_loader
    table = Prato.table(Company) do
      ruby_column("Fabulous Output")
      ruby_loader("Fabulous Output") do |records, _|
        records.map { |r| [r.id, "tested: #{r.id}"] }.to_h
      end
    end

    result = table.full(Company.all)
    assert_equal(
      [
        { "Fabulous Output": "tested: 1" },
        { "Fabulous Output": "tested: 2" }
      ], result[:entries]
    )
  end

  def test_single_argument_hash_symbol_symbol_with_loader
    table = Prato.table(Company) do
      ruby_column(output_name: :loader_name)
      ruby_loader(:loader_name) do |records, _|
        records.map { |r| [r.id, "tested: #{r.id}"] }.to_h
      end
    end

    result = table.full(Company.all)
    assert_equal(
      [
        { outputName: "tested: 1" },
        { outputName: "tested: 2" }
      ], result[:entries]
    )
  end

  def test_single_argument_hash_string_symbol_with_loader
    table = Prato.table(Company) do
      ruby_column("The Output" => :output_name)
      ruby_loader(:output_name) do |records, _|
        records.map { |r| [r.id, "tested: #{r.id}"] }.to_h
      end
    end

    result = table.full(Company.all)
    assert_equal(
      [
        { "The Output": "tested: 1" },
        { "The Output": "tested: 2" }
      ], result[:entries]
    )
  end
end

class TestApiRubyColumnSingleArgumentWithConstantKeyWithBlock < Minitest::Test
  include TestPratoApiRubyColumn

  def test_single_argument_symbol_with_constant_key_with_block
    table = Prato.table(Company) do
      ruby_column(:output, key: "testing") do |_, _|
        { "testing" => "tested" }
      end
    end

    validate(table, :output)
  end

  def test_single_argument_string_with_constant_key_with_block
    table = Prato.table(Company) do
      ruby_column("Fabulous Output", key: "testing") do |_, _|
        { "testing" => "tested" }
      end
    end

    validate(table, :"Fabulous Output")
  end

  def test_single_argument_hash_symbol_symbol_with_constant_key_with_block
    table = Prato.table(Company) do
      ruby_column(output_name: :loader_name, key: "testing") do |_, _|
        { "testing" => "tested" }
      end
    end

    validate(table, :outputName)
  end

  def test_single_argument_hash_string_symbol_with_constant_key_with_block
    table = Prato.table(Company) do
      ruby_column("The Output" => :output_name, key: "testing") do |_, _|
        { "testing" => "tested" }
      end
    end

    validate(table, :"The Output")
  end
end

class TestApiRubyColumnSingleArgumentWithConstantKeyWithLoader < Minitest::Test
  include TestPratoApiRubyColumn

  def test_single_argument_symbol_with_constant_key_with_loader
    table = Prato.table(Company) do
      ruby_column(:output, key: "testing")
      ruby_loader(:output) do |_, _|
        { "testing" => "tested" }
      end
    end

    validate(table, :output)
  end

  def test_single_argument_string_with_constant_key_with_loader
    table = Prato.table(Company) do
      ruby_column("Fabulous Output", key: "testing")
      ruby_loader("Fabulous Output") do |_, _|
        { "testing" => "tested" }
      end
    end

    validate(table, :"Fabulous Output")
  end

  def test_single_argument_hash_symbol_symbol_with_constant_key_with_loader
    table = Prato.table(Company) do
      ruby_column(output_name: :loader_name, key: "testing")
      ruby_loader(:loader_name) do |_, _|
        { "testing" => "tested" }
      end
    end

    validate(table, :outputName)
  end

  def test_single_argument_hash_string_symbol_with_constant_key_with_loader
    table = Prato.table(Company) do
      ruby_column("The Output" => :output_name, key: "testing")
      ruby_loader(:output_name) do |_, _|
        { "testing" => "tested" }
      end
    end

    validate(table, :"The Output")
  end
end

class TestApiRubyColumnTwoArgumentsWithBlock < Minitest::Test
  include TestPratoApiRubyColumn

  def test_two_arguments_symbol_symbol_with_block
    table = Prato.table(Company) do
      ruby_column(:very_nice_output, :loader_id) do |records, _|
        records.map { |r| [r.id, "tested: #{r.id}"] }.to_h
      end
    end

    result = table.full(Company.all)
    assert_equal(
      [
        { veryNiceOutput: "tested: 1" },
        { veryNiceOutput: "tested: 2" }
      ], result[:entries]
    )
  end

  def test_two_arguments_string_symbol_with_block
    table = Prato.table(Company) do
      ruby_column("Fabulous Output", :loader_id) do |records, _|
        records.map { |r| [r.id, "tested: #{r.id}"] }.to_h
      end
    end

    result = table.full(Company.all)
    assert_equal(
      [
        { "Fabulous Output": "tested: 1" },
        { "Fabulous Output": "tested: 2" }
      ], result[:entries]
    )
  end
end

class TestApiRubyColumnTwoArgumentsWithLoader < Minitest::Test
  include TestPratoApiRubyColumn

  def test_two_arguments_symbol_symbol_with_loader
    table = Prato.table(Company) do
      ruby_column(:very_nice_output, :loader_id)
      ruby_loader(:loader_id) do |records, _|
        records.map { |r| [r.id, "tested: #{r.id}"] }.to_h
      end
    end

    result = table.full(Company.all)
    assert_equal(
      [
        { veryNiceOutput: "tested: 1" },
        { veryNiceOutput: "tested: 2" }
      ], result[:entries]
    )
  end

  def test_two_arguments_string_symbol_with_loader
    table = Prato.table(Company) do
      ruby_column("Fabulous Output", :loader_id)
      ruby_loader(:loader_id) do |records, _|
        records.map { |r| [r.id, "tested: #{r.id}"] }.to_h
      end
    end

    result = table.full(Company.all)
    assert_equal(
      [
        { "Fabulous Output": "tested: 1" },
        { "Fabulous Output": "tested: 2" }
      ], result[:entries]
    )
  end
end

class TestApiRubyColumnTwoArgumentsWithConstantKeyBlock < Minitest::Test
  include TestPratoApiRubyColumn

  def test_two_arguments_symbol_symbol_with_constant_key_block
    table = Prato.table(Company) do
      ruby_column(:output, :random_loader_id, key: "testing") do |_, _|
        { "testing" => "tested" }
      end
    end

    validate(table, :output)
  end

  def test_two_arguments_string_symbol_with_constant_key_block
    table = Prato.table(Company) do
      ruby_column("FabulousOutput", :random_loader_id, key: "testing") do |_, _|
        { "testing" => "tested" }
      end
    end

    validate(table, :"FabulousOutput")
  end
end

class TestApiRubyColumnTwoArgumentsWithConstantKeyLoader < Minitest::Test
  include TestPratoApiRubyColumn

  def test_two_arguments_symbol_symbol_with_constant_key_loader
    table = Prato.table(Company) do
      ruby_column(:output, :random_loader_id, key: "testing")
      ruby_loader(:random_loader_id) do |_, _|
        { "testing" => "tested" }
      end
    end

    validate(table, :output)
  end

  def test_two_arguments_string_symbol_with_constant_key_loader
    table = Prato.table(Company) do
      ruby_column("FabulousOutput", :random_loader_id, key: "testing")
      ruby_loader(:random_loader_id) do |_, _|
        { "testing" => "tested" }
      end
    end

    validate(table, :"FabulousOutput")
  end
end



class TestApiRubyColumnSingleArgumentWithSymbolKeyWithBlock < Minitest::Test

end

class TestApiRubyColumnSingleArgumentWithSymbolKeyWithLoader < Minitest::Test

end

class TestApiRubyColumnTwoArgumentsWithSymbolKeyWithBlock < Minitest::Test

end

class TestApiRubyColumnTwoArgumentsWithSymbolKeyWithLoader < Minitest::Test

end

class TestApiRubyColumn < Minitest::Test
  include TestPratoApiRubyColumn

  def test_single_argument_with_dependencies_with_block
    table = Prato.table(User) do
      ruby_column(:company_stuff, key: ->(r) { r.company&.id }, includes: :company) do |users, _|
        companies = users.map(&:company).compact.uniq(&:id)
        companies.map { |c| [c.id, "I am company #{c.name}"]}.to_h
      end
      ruby_column(:number_companies, key: "No key") do |users, ctx|
        companies = ctx[:company_stuff]
        { 'No key' => companies.size }
      end
    end

    result = table.full(User.all)
    assert_equal(
      [
        {companyStuff: "I am company Acme Corp", numberCompanies: 2 },
        {companyStuff: "I am company Acme Corp", numberCompanies: 2 },
        {companyStuff: "I am company Globex", numberCompanies: 2 },
        {companyStuff: nil, numberCompanies: 2}],
      result[:entries]
    )
  end

  def test_single_argument_with_dependencies_with_separate_loader_with_block
    table = Prato.table(User) do
      ruby_column(:number_companies, key: "total", includes: :company) do |_, ctx|
        companies = ctx[:company_stuff]
        { "total" => companies.size }
      end

      ruby_loader(:company_stuff) do |users, |
        companies = users.map(&:company).compact.uniq(&:id)
        companies.map { |c| [c.id, "I am company #{c.name}"]}
      end
    end

    result = table.full(User.all)
    assert_equal(
      [
        { numberCompanies: 2 },
        { numberCompanies: 2 },
        { numberCompanies: 2 },
        { numberCompanies: 2 }
      ], result[:entries]
    )
  end
end

class TestApiRubyColumnFilterOption < Minitest::Test
  def test_ruby_column_filter_rejects_invalid_option_type
    assert_raises(ArgumentError) do
      Prato.table(Company) do
        ruby_column(:output, filter: Object.new) do |records, _|
          records.to_h { |record| [record.id, "tested: #{record.id}"] }
        end
      end
    end
  end

  def test_ruby_column_filter_rejects_invalid_array_entries
    assert_raises(ArgumentError) do
      Prato.table(Company) do
        ruby_column(:output, filter: [:eq, 123]) do |records, _|
          records.to_h { |record| [record.id, "tested: #{record.id}"] }
        end
      end
    end
  end

  def test_ruby_column_filter_rejects_string_operators
    assert_raises(ArgumentError) do
      Prato.table(Company) do
        ruby_column(:output, filter: %w[eq contains]) do |records, _|
          records.to_h { |record| [record.id, "tested: #{record.id}"] }
        end
      end
    end
  end
end

class TestApiRubyColumnIncludes < Minitest::Test
  def test_ruby_column_includes_preloads_associations_for_inline_loader
    table = Prato.table(User) do
      ruby_column(:company_name, key: :id, includes: :company) do |records, _|
        index_records_by_id(records) { |user| user.company&.name }
      end
    end

    assert_select_query_count(2) do
      result = table.full(User.order(:id))

      assert_equal ["Acme Corp", "Acme Corp", "Globex", nil], result[:entries].map { |entry| entry[:companyName] }
    end
  end

  def test_ruby_column_includes_accept_strings_like_rails
    table = Prato.table(User) do
      ruby_column(:company_name, key: :id, includes: "company") do |records, _|
        index_records_by_id(records) { |user| user.company&.name }
      end
    end

    result = table.full(User.order(:id))

    assert_equal ["Acme Corp", "Acme Corp", "Globex", nil], result[:entries].map { |entry| entry[:companyName] }
  end

  def test_ruby_column_includes_support_nested_rails_shapes_with_loader
    table = Prato.table(Comment) do
      ruby_column(:comment_context, key: :id, includes: [:user, { post: { user: :company } }])

      ruby_loader(:comment_context) do |records, _|
        index_records_by_id(records) do |comment|
          [comment.user.name, comment.post.user.company&.name].join(" / ")
        end
      end
    end

    result = table.full(Comment.order(:id))

    assert_equal [
      "Bob / Acme Corp",
      "Carol / Acme Corp",
      "Dave / Acme Corp"
    ], result[:entries].first(3).map { |entry| entry[:commentContext] }
  end

end

class TestApiRubyLoaderIncludes < Minitest::Test
  def test_ruby_loader_includes_preloads_associations_for_separate_loader
    table = Prato.table(User) do
      ruby_column(:company_name, key: :id)

      ruby_loader(:company_name, includes: :company) do |records, _|
        index_records_by_id(records) { |user| user.company&.name }
      end
    end

    assert_select_query_count(2) do
      result = table.full(User.order(:id))

      assert_equal ["Acme Corp", "Acme Corp", "Globex", nil], result[:entries].map { |entry| entry[:companyName] }
    end
  end

end
