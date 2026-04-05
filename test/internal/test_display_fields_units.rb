# frozen_string_literal: true

require "test_helper"

module TestDisplayFields
  private

  def field(*parts)
    Prato::Query::FieldPath.join(parts)
  end

  def filter(field_name, operator, value)
    Prato::Query::Filter.new(field_name, operator, value)
  end

  def sort(field_name, order = :asc)
    Prato::Query::Sort.new(field_name, order)
  end

  def query_params(fields: nil, filters: nil, sorts: nil)
    Prato::Query::Parameters.new(fields: fields, filters: filters, sorts: sorts)
  end

  def alice_entry(table, params: nil)
    table.to_table(User.where(name: "Alice"), params: params)[:entries].first
  end

  def build_mixed_user_table
    Prato.table(User) do
      column(:name)
      column(company_name: %i[company name])
      column(:age_plus_ten, expression: "users.age + 10")
      column(:post_count, count: :posts)

      ruby_column(:name_upcase, key: :id) do |records, _|
        index_records_by_id(records) { |user| user.name.upcase }
      end
    end
  end

  def build_mixed_user_section_table
    Prato.table(User) do
      column(:name)

      section(:profile) do
        column(:age)
        column(company_name: %i[company name])
        column(:age_plus_ten, expression: "users.age + 10")
        column(:post_count, count: :posts)

        ruby_column(:name_upcase, key: :id) do |records, _|
          index_records_by_id(records) { |user| user.name.upcase }
        end
      end
    end
  end
end

class TestDisplayFieldsDefaults < Minitest::Test
  include TestDisplayFields

  def test_nil_params_serialize_all_visible_fields_for_mixed_columns
    table = build_mixed_user_table

    assert_equal(
      {
        name: "Alice",
        companyName: "Acme Corp",
        agePlusTen: 40,
        postCount: 4,
        nameUpcase: "ALICE"
      },
      alice_entry(table)
    )
  end
end

class TestDisplayFieldsSelection < Minitest::Test
  include TestDisplayFields

  def test_requested_fields_limit_output_after_ruby_filter_materialization
    table = build_mixed_user_table

    result = table.to_table(
      User.all,
      params: query_params(
        fields: [field(:name), field(:age_plus_ten), field(:post_count)],
        filters: filter(field(:name_upcase), :eq, "ALICE")
      )
    )

    assert_equal(
      [
        {
          name: "Alice",
          agePlusTen: 40,
          postCount: 4
        }
      ],
      result[:entries]
    )
  end

  def test_requested_fields_limit_output_after_ruby_sort_materialization
    table = build_mixed_user_table

    result = table.to_table(
      User.order(:id),
      params: query_params(
        fields: [field(:name), field(:age_plus_ten)],
        sorts: [sort(field(:name_upcase), :asc)]
      )
    )

    assert_equal(
      [
        { name: "Alice", agePlusTen: 40 },
        { name: "Bob", agePlusTen: 27 },
        { name: "Carol", agePlusTen: 35 },
        { name: "Dave", agePlusTen: 50 }
      ],
      result[:entries]
    )
  end

  def test_requested_section_fields_limit_output_after_ruby_filter_materialization
    table = build_mixed_user_section_table

    result = table.to_table(
      User.all,
      params: query_params(
        fields: [field(:name), field(:profile, :age_plus_ten), field(:profile, :post_count)],
        filters: filter(field(:profile, :name_upcase), :eq, "ALICE")
      )
    )

    assert_equal(
      [
        {
          name: "Alice",
          profile: {
            agePlusTen: 40,
            postCount: 4
          }
        }
      ],
      result[:entries]
    )
  end

  def test_requested_section_fields_limit_output_via_raw_dotted_params
    table = build_mixed_user_section_table

    assert_equal(
      {
        name: "Alice",
        profile: {
          agePlusTen: 40
        }
      },
      alice_entry(
        table,
        params: {
          fields: ["name", "profile.agePlusTen"]
        }
      )
    )
  end
end

class TestDisplayFieldsValidation < Minitest::Test
  include TestDisplayFields

  def test_requesting_query_only_field_returns_empty_result_by_default
    table = Prato.table(Post) do
      column(:title)
      query_column(author_name: %i[user name])
    end

    result = table.to_table(
      Post.order(:id),
      params: query_params(fields: [field(:title), field(:author_name)])
    )

    assert_equal [], result[:entries]
    assert_equal 0, result[:totalCount]
  end

  def test_requesting_query_only_field_raises_when_invalid_input_is_configured_to_raise
    table = Prato.table(Post) do
      configure(on_invalid_input: :raise)
      column(:title)
      query_column(author_name: %i[user name])
    end

    assert_raises(ArgumentError) do
      table.to_table(
        Post.order(:id),
        params: query_params(fields: [field(:title), field(:author_name)])
      )
    end
  end

  def test_requesting_unknown_field_returns_empty_result_by_default
    table = Prato.table(User) do
      column(:name)
    end

    result = table.to_table(
      User.order(:id),
      params: query_params(fields: [field(:name), field(:unknown_field)])
    )

    assert_equal [], result[:entries]
    assert_equal 0, result[:totalCount]
  end
end
