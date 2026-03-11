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
        column = ::Prato::Types::Column.new(accessor, display: display, scope: scope)

        @draft_columns << DraftColumn.new(name, column)
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

        @draft_columns << DraftColumn.new(name, column)
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
          @draft_columns << DraftColumn.new(section_name, nested.column)
        end
      end

      def inner_ruby_loader(id, &block)
        @ruby_loaders ||= {}
        @ruby_loaders[id] = block
      end

      def inner_config(config)
        @config = config
      end

      def validate_and_update_keys!
        @draft_columns.each do |draft|
          column_display_id = transform_draft_name(draft, config.key_transformation)

          if @columns.key?(column_display_id)
            validate_ruby_loader!(draft, @loaders)
            raise ArgumentError.new("Column '#{column_display_id}' has already been defined.")
          end

          @columns[column_display_id] = draft.column
        end
        @draft_columns.clear
      end

      def validate_ruby_loader!(draft, loaders)
        column = draft.column
        return unless column.is_a?(Prato::Types::RubyColumn)

        loader_name = column.loader

        if loader_name.nil?
          raise ArgumentError, "Ruby column '#{draft.name || column.key}' is missing a loader."
        end
        if loaders.nil?
          raise ArgumentError, "No ruby loader registered for '#{loader_name}'."
        end
        loader = loaders[loader_name]
        unless loaders.key?(loader_name)
          raise ArgumentError, "No ruby loader registered for '#{loader_name}'."
        end
        unless loader.respond_to?(:call)
          raise ArgumentError, "Ruby loader '#{loader_name}' must respond to #call."
        end
      end

      def all_fields
        columns.keys
      end

      private

      def add_draft_column(name, column)
        @validated = false
        @draft_columns << DraftColumn.new(name, column)
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
