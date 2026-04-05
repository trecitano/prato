# frozen_string_literal: true

require "test_helper"

class TestFieldPath < Minitest::Test
  def test_single_symbol
    assert_equal :name, Prato::Query::FieldResolver.join([:name])
  end

  def test_single_string
    assert_equal :name, Prato::Query::FieldResolver.join(["name"])
  end

  def test_bare_symbol_without_array
    assert_equal :name, Prato::Query::FieldResolver.join(:name)
  end

  def test_bare_string_without_array
    assert_equal :name, Prato::Query::FieldResolver.join("name")
  end

  def test_two_parts
    assert_equal :"section___column", Prato::Query::FieldResolver.join([:section, :column])
  end

  def test_three_parts
    assert_equal :"a___b___c", Prato::Query::FieldResolver.join([:a, :b, :c])
  end

  def test_mixed_strings_and_symbols
    assert_equal :"outer___inner___field", Prato::Query::FieldResolver.join(["outer", :inner, "field"])
  end

  def test_parts_with_spaces
    assert_equal :"Even Inner Section___twice_inner___age",
                 Prato::Query::FieldResolver.join(["Even Inner Section", :twice_inner, :age])
  end
end