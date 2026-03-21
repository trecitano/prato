# frozen_string_literal: true

require "test_helper"

class TestApiSection < Minitest::Test
  def test_simple_section
    table = Prato.table(User) do
      column(:name)
      section(:company_info) do
        column(name: %i[company name])
      end
    end

    result = table.to_table(User.all)
    validate(table, :name)
  end

  def test_double_nested_section
    table = Prato.table(User) do
      column(:name)
      section(:company_info) do
        column(company_name: %i[company name])
        section(:name) do
          column(inner_name: :name)
        end
      end
    end

    result = table.to_table(User.all)
    assert_equal(
      [
        { name: "Alice", companyInfo: { companyName: "Acme Corp", name: { innerName: "Alice" } } },
        { name: "Bob",   companyInfo: { companyName: "Acme Corp", name: { innerName: "Bob" } } },
        { name: "Carol", companyInfo: { companyName: "Globex",    name: { innerName: "Carol" } } },
        { name: "Dave",  companyInfo: { companyName: nil,         name: { innerName: "Dave" } } }
      ], result[:entries]
    )
  end
end
