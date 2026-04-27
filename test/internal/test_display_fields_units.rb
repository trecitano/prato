# frozen_string_literal: true

require "test_helper"

module TestDisplayFields
  private

  def alice_entry(table, params: nil)
    table.full(User.where(name: "Alice"), params).first
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

    result = table.full(
      User.all,
      query_params(
        fields: [query_field_path(:name), query_field_path(:age_plus_ten), query_field_path(:post_count)],
        filters: query_filter(:name_upcase, :eq, "ALICE")
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
      result
    )
  end

  def test_requested_fields_limit_output_after_ruby_sort_materialization
    table = build_mixed_user_table

    result = table.full(
      User.order(:id),
      query_params(
        fields: [query_field_path(:name), query_field_path(:age_plus_ten)],
        sorts: [query_sort(:name_upcase, :asc)]
      )
    )

    assert_equal(
      [
        { name: "Alice", agePlusTen: 40 },
        { name: "Bob", agePlusTen: 27 },
        { name: "Carol", agePlusTen: 35 },
        { name: "Dave", agePlusTen: 50 }
      ],
      result
    )
  end

  def test_requested_section_fields_limit_output_after_ruby_filter_materialization
    table = build_mixed_user_section_table

    result = table.full(
      User.all,
      query_params(
        fields: [query_field_path(:name), query_field_path(:profile, :age_plus_ten),
                 query_field_path(:profile, :post_count)],
        filters: query_filter(%i[profile name_upcase], :eq, "ALICE")
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
      result
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

    result = table.full(
      Post.order(:id),
      query_params(fields: [query_field_path(:title), query_field_path(:author_name)])
    )

    assert_equal [], result
  end

  def test_requesting_query_only_field_raises_when_invalid_input_is_configured_to_raise
    table = Prato.table(Post) do
      configure(on_invalid_input: :raise)
      column(:title)
      query_column(author_name: %i[user name])
    end

    assert_raises(ArgumentError) do
      table.full(
        Post.order(:id),
        query_params(fields: [query_field_path(:title), query_field_path(:author_name)])
      )
    end
  end

  def test_requesting_unknown_field_returns_empty_result_by_default
    table = Prato.table(User) do
      column(:name)
    end

    result = table.full(
      User.order(:id),
      query_params(fields: [query_field_path(:name), query_field_path(:unknown_field)])
    )

    assert_equal [], result
  end
end
