# frozen_string_literal: true

require "test_helper"

class TestApiConfigureDefaults < Minitest::Test
  def test_setup_returns_configuration_with_defaults
    config = Prato.setup
    assert_equal 20, config.default_page_size
    assert_equal 100, config.maximum_page_size
    assert_equal :camelCase, config.key_transformation
    assert_equal :empty, config.on_invalid_input
    assert_nil config.default_only
    assert_equal :display, config.default_ruby_column_only
  end
end

class TestApiConfigureKeyTransformation < Minitest::Test
  def test_camel_case_default
    table = Prato.table(User) do
      column(:post_count, :name)
    end

    output = table.full(User.where(name: "Alice"))
    assert_equal "Alice", output.first[:postCount]
  end

  def test_camel_case_default_weird_case
    table = Prato.table(User) do
      column(:"kebaB-Case99 yEs", :name)
    end

    output = table.full(User.all)
    assert_equal :kebaBCase99YEs, output.first.keys.first
  end

  def test_snake_case_from_camel
    table = Prato.table(User) do
      configure(key_transformation: :snake_case)
      column(:postCount, :name)
    end

    output = table.full(User.all)
    assert_equal :post_count, output.first.keys.first
  end

  def test_snake_case_to_snake_case
    table = Prato.table(User) do
      configure(key_transformation: :snake_case)
      column(:post_count, :name)
    end

    output = table.full(User.all)
    assert_equal :post_count, output.first.keys.first
  end

  def test_snake_case_weird_case
    table = Prato.table(User) do
      configure(key_transformation: :snake_case)
      column(:"kebaB-Case99 yEs", :name)
    end


    output = table.full(User.all)
    assert_equal :keba_b_case99_y_es, output.first.keys.first
  end

  def test_none_with_snake
    table = Prato.table(User) do
      configure(key_transformation: :none)
      column(:post_count, :name)
    end

    output = table.full(User.all)
    assert_equal :post_count, output.first.keys.first
  end

  def test_none_with_pascal_case
    table = Prato.table(User) do
      configure(key_transformation: :none)
      column(:PostCount, :name)
    end

    output = table.full(User.all)
    assert_equal :PostCount, output.first.keys.first
  end

  def test_none_with_random_casing
    table = Prato.table(User) do
      configure(key_transformation: :none)
      column(:"kebaB-Case", :name)
    end

    output = table.full(User.all)
    assert_equal :"kebaB-Case", output.first.keys.first
  end

  def test_invalid_key_transformation_raises
    config = Prato.setup
    assert_raises(ArgumentError) { config.key_transformation = :kebab_case }
  end

  def test_invalid_key_in_configure_function_transformation_raises
    assert_raises(ArgumentError) do
      Prato.table(User) do
        configure(key_transformation: :kebab_case)
      end
    end
  end
end