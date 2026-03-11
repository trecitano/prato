# frozen_string_literal: true

module Prato
  module Internal
    class Specification

      # Maps accessor (key) to Column information
      # The sections are flattened.
      # Example:
      # {
      #   [:id]: Column,
      #   [:name]: Column
      #   [:associatedData, :id]: Column
      #   [:associatedData, :status]: RubyColumn
      #   [:created_at]: Column
      # }
      attr_reader :columns

      # Stores the mapping of fields and names.
      # Example:
      # [
      #   [:id, nil]
      #   [:associated_data, :id]
      #   [:associated_data, :special_name]
      #   [:associated_data, :status, :frontendstatus]
      #   [:created_at]
      # ]
      attr_reader :fields

      attr_reader :ruby_loaders

      attr_reader :config

      attr_reader :draft_columns

      def initialize
        @columns = {}
        @config = Prato::Configuration.config
        @validated = false
        @draft_columns = []
      end

      def inner_column(*args, **kwargs)
        if args.any?
          name_map = args.first
          display = kwargs[:display]
          scope = kwargs[:scope]
        else
          display = kwargs.delete(:display)
          scope = kwargs.delete(:scope)
          name_map = kwargs
        end

        name, accessor = parse_name_map(name_map)
        col = ::Prato::Types::Column.new(accessor, display: display, scope: scope)

        add_draft_column(name, col)
      end

      def inner_ruby_column(*args, **kwargs)
        if args.any?
          name_map = args.first
          key = kwargs[:key]
        else
          key = kwargs.delete(:key)
          name_map = kwargs
        end

        name, loader = parse_name_map(name_map)
        accessor = parse_accessor(key)
        column = ::Prato::Types::RubyColumn.new(loader, key: accessor)

        add_draft_column(name, column)
      end

      def inner_section(id, &block)
        section = SectionBuilder.new

        if block_given?
          section.instance_exec(&block)
        else
          raise ArgumentError, "No block given to section"
        end

        section.spec.draft_columns.each do |nested|
          section_name = [id, nested.name]
          add_draft_column(section_name, nested.column)
        end
      end

      def inner_ruby_loaders(ruby_loaders)
        @ruby_loaders = ruby_loaders
        @validated = false
      end

      def inner_config(config)
        @config = config
        @validated = false
      end

      def validate_and_update_keys!
        @draft_columns.each do |draft|
          column_display_id = transform_draft_name(draft, config.key_transformation)

          if @columns.key?(column_display_id)
            raise ArgumentError.new("Column '#{column_display_id}' has already been defined.")
          end

          @columns[column_display_id] = draft.column
        end
        @draft_columns.clear
      end

      def all_fields
        @all_fields ||= extract_fields(columns)
      end

      private

      def add_draft_column(name, column)
        @validated = false
        @draft_columns << DraftColumn.new(name, column)
      end

      # Given a list of columns, returns an array of either symbols or arrays of symbols
      def extract_fields(columns)
        columns.map do |id, col|
          if col.is_a?(Types::Section)
            extract_fields(col.columns)
          else
            col.id
          end
        end
      end

      def parse_name_map(name_map)
        case name_map
        when Symbol, Array
          [nil, name_map]
        when Hash
          entry = name_map.first
          [entry.first, entry.second]
        else
          raise ArgumentError, "name_map must be a Symbol or Array"
        end
      end

      def parse_accessor(value)
        case value
        when Symbol
          value
        when Hash
          flatten_hash_to_array(value)
        else
          value
        end
      end

      def flatten_hash_to_array(hash)
        return [] if hash.empty?

        key, value = hash.first
        case value
        when Symbol
          [key, value]
        when Hash
          [key] + flatten_hash_to_array(value)
        else
          [key]
        end
      end

      def normalize_config_keys(config_hash)
        config_hash.each_with_object({}) do |(key, value), result|
          result[key.respond_to?(:to_sym) ? key.to_sym : key] = value
        end
      end

      def transform_draft_name(draft, transformation)
        name = draft.name

        return name unless Array(name).last.nil?

        column = draft.column
        name = if column.is_a?(Prato::Types::Column)
                 Array(column.accessor).last
               else
                 column.loader
               end

        transformed_name = case transformation
                           when :camelCase
                             to_camel_case(name).to_sym
                           when :snake_case
                             to_snake_case(name).to_sym
                           when :none
                             name.to_sym
                           end

        if name.is_a?(Array)
          name.tap { |n| n[-1] = transformed_name }
        else
          transformed_name
        end
      end

      def to_camel_case(value)
        parts = to_snake_case(value).split("_")
        parts.first + parts.drop(1).map(&:capitalize).join
      end
      def to_snake_case(value)
        value
          .to_s
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .tr("-", "_")
          .downcase
      end
    end

    class DraftColumn
      attr_reader :name, :column

      def initialize(name, column)
        @name = name
        @column = column
      end
    end

    class SectionBuilder
      attr_reader :spec

      def initialize
        @spec = Specification.new
      end
      def column(*args, **kwargs)
        @spec.inner_column(*args, **kwargs)
        self
      end
      def ruby_column(*args, **kwargs)
        @spec.inner_ruby_column(*args, **kwargs)
        self
      end
      def section(id, &block)
        @spec.inner_section(id, &block)
        self
      end
    end

    private_constant :DraftColumn
    private_constant :SectionBuilder
  end
end
