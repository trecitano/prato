# frozen_string_literal: true

require "test_helper"

module TestPratoApiSection
  private

  def alice_entry(table)
    table.to_table(User.where(name: "Alice"))[:entries].first
  end

  def names_for(table, scope: User.all, params: nil)
    table.to_table(scope, params: params)[:entries].map { |entry| entry[:name] }
  end

  def titles_for(table, scope: Post.all, params: nil)
    table.to_table(scope, params: params)[:entries].map { |entry| entry[:title] }
  end
end

class TestApiSectionSerialization < Minitest::Test
  include TestPratoApiSection

  def test_section_serializes_nested_hash_for_mixed_column_types
    table = Prato.table(User) do
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

    assert_equal(
      {
        name: "Alice",
        profile: {
          age: 30,
          companyName: "Acme Corp",
          agePlusTen: 40,
          postCount: 4,
          nameUpcase: "ALICE"
        }
      },
      alice_entry(table)
    )
  end

  def test_nested_sections_serialize_recursively
    table = Prato.table(Comment) do
      section(:post_info) do
        section(:author) do
          column(:name, %i[post user name])
        end

        section(:category) do
          section(:parent) do
            column(:name, %i[post category parent_category name])
          end
        end
      end
    end

    entry = table.to_table(Comment.order(:id).limit(1))[:entries].first

    assert_equal(
      {
        postInfo: {
          author: { name: "Alice" },
          category: { parent: { name: "Technology" } }
        }
      },
      entry
    )
  end

  def test_same_leaf_name_can_be_reused_in_different_sections
    table = Prato.table(User) do
      section(:public_profile) do
        column(:name)
      end

      section(:company_profile) do
        column(:name, %i[company name])
      end
    end

    assert_equal(
      {
        publicProfile: { name: "Alice" },
        companyProfile: { name: "Acme Corp" }
      },
      alice_entry(table)
    )
  end

  def test_duplicate_nested_paths_raise
    error = assert_raises(ArgumentError) do
      Prato.table(User) do
        section(:profile) do
          column(:name)
          column(:name)
        end
      end
    end

    assert_match(/profile___name/, error.message)
  end
end

class TestApiSectionKeyTransformation < Minitest::Test
  include TestPratoApiSection

  def test_section_keys_follow_configured_key_transformation
    table = Prato.table(User) do
      configure(key_transformation: :snake_case)

      section(:postInfo) do
        column(:authorName, :name)
      end
    end

    assert_equal(
      {
        post_info: {
          author_name: "Alice"
        }
      },
      alice_entry(table)
    )
  end

  def test_string_section_and_column_names_are_preserved
    table = Prato.table(User) do
      section("Profile Info") do
        column("Company Name", %i[company name])
      end
    end

    assert_equal(
      {
        "Profile Info": {
          "Company Name": "Acme Corp"
        }
      },
      alice_entry(table)
    )
  end
end

class TestApiSectionQuerying < Minitest::Test
  include TestPratoApiSection

  def test_section_fields_can_be_filtered_via_dotted_raw_params
    table = Prato.table(User) do
      column(:name)

      section(:profile) do
        column(company_name: %i[company name])
      end
    end

    result = table.to_table(
      User.order(:id),
      params: {
        filters: [{ field: "profile.companyName", operator: "eq", value: "Acme Corp" }]
      }
    )

    assert_equal(%w[Alice Bob], result[:entries].map { |entry| entry[:name] })
    assert_equal 2, result[:totalCount]
  end

  def test_section_fields_can_be_sorted_via_dotted_raw_params
    table = Prato.table(User) do
      column(:name)

      section(:profile) do
        column(:age)
      end
    end

    assert_equal(
      %w[Dave Alice Carol Bob],
      names_for(
        table,
        params: {
          sorts: [{ field: "profile.age", order: "desc" }]
        }
      )
    )
  end

  def test_nested_association_section_fields_can_be_sorted_via_dotted_raw_params
    table = Prato.table(Post) do
      column(:title)

      section(:post_info) do
        section(:author) do
          column(:name, %i[user name])
        end
      end
    end

    assert_equal(
      [
        "Draft",
        "Hello",
        "More Ruby",
        "Ruby tips",
        "Learning Rails",
        "Young dev",
        "Finance tips",
        "Market update",
        "Unpublished"
      ],
      titles_for(
        table,
        params: {
          sorts: [
            { field: "postInfo.author.name", order: "asc" },
            { field: "title", order: "asc" }
          ]
        }
      )
    )
  end

  def test_expression_section_fields_can_be_sorted_via_dotted_raw_params
    table = Prato.table(User) do
      column(:name)

      section(:computed) do
        column(:age_plus_ten, expression: "users.age + 10")
      end
    end

    assert_equal(
      %w[Dave Alice Carol Bob],
      names_for(
        table,
        params: {
          sorts: [{ field: "computed.agePlusTen", order: "desc" }]
        }
      )
    )
  end

  def test_aggregate_section_fields_can_be_sorted_via_dotted_raw_params
    table = Prato.table(User) do
      column(:name)

      section(:stats) do
        column(:post_count, count: :posts)
      end
    end

    assert_equal(
      %w[Alice Carol Bob Dave],
      names_for(
        table,
        params: {
          sorts: [{ field: "stats.postCount", order: "desc" }]
        }
      )
    )
  end

  def test_ruby_section_fields_can_be_sorted_via_dotted_raw_params
    table = Prato.table(User) do
      column(:name)

      section(:computed) do
        ruby_column(:post_count, key: :id) do |records, _|
          counts = Post.group(:user_id).count
          index_records_by_id(records) { |user| counts.fetch(user.id, 0) }
        end
      end
    end

    assert_equal(
      %w[Alice Carol Bob Dave],
      names_for(
        table,
        params: {
          sorts: [{ field: "computed.postCount", order: "desc" }]
        }
      )
    )
  end

  def test_ruby_section_fields_with_nil_values_can_be_sorted_via_dotted_raw_params
    table = Prato.table(User) do
      column(:name)

      section(:computed) do
        ruby_column(:company_name, key: :id, includes: :company) do |records, _|
          index_records_by_id(records) { |user| user.company&.name }
        end
      end
    end

    assert_equal(
      %w[Dave Carol Alice Bob],
      names_for(
        table,
        params: {
          sorts: [
            { field: "computed.companyName", order: "desc" },
            { field: "name", order: "asc" }
          ]
        }
      )
    )
  end
end

class TestApiSectionValidation < Minitest::Test
  def test_section_requires_a_block
    assert_raises(ArgumentError) do
      Prato.table(User) { section(:profile) }
    end
  end

  def test_section_block_must_not_accept_arguments
    assert_raises(ArgumentError) do
      Prato.table(User) do
        section(:profile) { |_builder| column(:name) }
      end
    end
  end
end
