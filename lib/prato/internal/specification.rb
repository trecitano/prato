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

      attr_reader :ruby_loaders, :config, :draft_columns

      def initialize
        @columns = {}
        @config = Prato::Configuration.config
        @validated = false
        @draft_columns = []
      end

      AGGREGATE_FUNCTIONS = %i[count sum avg min max].freeze
      RESERVED_COLUMN_SYMBOLS = (%i[format transform_record expression] + AGGREGATE_FUNCTIONS).freeze
      RESERVED_RUBY_COLUMN_SYMBOLS = %i[loader key].freeze

      def inner_column(*args, **kwargs)
        name_map, options = extract_name_and_options(args, kwargs, RESERVED_COLUMN_SYMBOLS)
        aggregate_function, aggregate_accessor = extract_aggregate(options)

        draft = if aggregate_function
                  column = ::Prato::Types::AggregateColumn.new(aggregate_function, aggregate_accessor, format: options[:format])
                  DraftColumn.new(nil, name_map, column)
                elsif options[:expression]
                  name, accessor = parse_name_map(name_map)
                  column = ::Prato::Types::ExpressionColumn.new(options[:expression], format: options[:format], transform_record: options[:transform_record])
                  DraftColumn.new(name, accessor, column)
                else
                  name, accessor = parse_name_map(name_map)
                  column = ::Prato::Types::Column.new(accessor, format: options[:format], transform_record: options[:transform_record])
                  DraftColumn.new(name, accessor, column)
                end

        @draft_columns << draft
      end

      # Either single symbol, following by keyword arguments,
      # or a list of keyword arguments.
      # ruby_column(frontendName: :loader_identification)
      # ruby_column(:loader_identification, key: [:posts, :id])
      def inner_ruby_column(*args, **_kwargs)
        name_map, = extract_name_and_options(args, %i[display scope] + AGGREGATE_FUNCTIONS)
        parse_name_map(name_map)

        name, loader = parse_name_map(name_map)
        accessor = parse_accessor(key)
        column = ::Prato::Types::RubyColumn.new(loader, key: accessor)

        @draft_columns << DraftColumn.new(name, nil, column)
      end

      def inner_section(id, &block)
        section = SectionBuilder.new

        raise ArgumentError, "No block given to section" unless block_given?

        section.instance_exec(&block)

        section.spec.draft_columns.each do |nested|
          draft = if nested.override_name.nil?
                    DraftColumn.new(nil, [id, nested.accessor_name], nested.column)
                  else
                    DraftColumn.new([id, nested.override_name], nil, nested.column)
                  end

          @draft_columns << draft
        end
      end

      def inner_ruby_loader(id, &block)
        @ruby_loaders ||= {}
        @ruby_loaders[id] = block
      end

      def inner_config(config)
        @config = config
      end

      def validate_associations!(scope)
        # TODO: Validate that column associations exist on the model
      end

      def validate_and_update_keys!(base_model)
        @draft_columns.each do |draft|
          column_display_id = transform_draft_name(draft, config.key_transformation)
          validate_ruby_loader!(draft, @loaders)

          if @columns.key?(column_display_id)
            raise ArgumentError, "Column '#{column_display_id}' has already been defined."
          end

          column = draft.column
          @columns[column_display_id] = column
          if column.is_a?(Types::Column) || column.is_a?(Types::ExpressionColumn) || column.is_a?(Types::AggregateColumn)
            column.resolve_arel!(base_model, column_display_id)
          end
        end
        @draft_columns.clear
      end

      def validate_ruby_loader!(draft, loaders)
        column = draft.column
        return unless column.is_a?(Prato::Types::RubyColumn)

        loader_name = column.loader

        raise ArgumentError, "Ruby column '#{draft.name || column.key}' is missing a loader." if loader_name.nil?
        raise ArgumentError, "No ruby loader registered for '#{loader_name}'." if loaders.nil?

        loader = loaders[loader_name]
        raise ArgumentError, "No ruby loader registered for '#{loader_name}'." unless loaders.key?(loader_name)
        return if loader.respond_to?(:call)

        raise ArgumentError, "Ruby loader '#{loader_name}' must respond to #call."
      end

      def all_fields
        columns.keys
      end

      def sql_only?(display_fields = nil)
        fields_to_check = display_fields || columns.keys
        fields_to_check.none? do |field|
          col = columns[field]
          col.is_a?(Types::RubyColumn) || (col.respond_to?(:transform_record) && col.transform_record)
        end
      end

      def column(field)
        @columns[field]
      end

      private

      def extract_name_and_options(args, kwargs, reserved)
        if args.any?
          [args.first, kwargs]
        else
          reserved = %i[format transform_record expression key] + AGGREGATE_FUNCTIONS
          option_keys = kwargs.keys & reserved
          options = kwargs.slice(*option_keys)
          name_map = kwargs.except(*reserved)
          [name_map, options]
        end
      end

      def add_draft_column(name, column)
        @validated = false
        @draft_columns << DraftColumn.new(name, column)
      end

      def extract_aggregate(kwargs)
        AGGREGATE_FUNCTIONS.each do |func|
          value = kwargs.delete(func)
          return [func, value] if value
        end
        nil
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
        config_hash.transform_keys do |key|
          key.respond_to?(:to_sym) ? key.to_sym : key
        end
      end

      def transform_draft_name(draft, transformation)
        return draft.override_name unless draft.override_name.nil?

        raw_name = Array(draft.accessor_name).last
        case transformation
         when :camelCase
           to_camel_case(raw_name).to_sym
         when :snake_case
           to_snake_case(raw_name).to_sym
         when :none
           raw_name.to_sym
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

      private_constant :RESERVED_COLUMN_SYMBOLS
      private_constant :RESERVED_RUBY_COLUMN_SYMBOLS
      private_constant :AGGREGATE_FUNCTIONS
    end

    class DraftColumn
      attr_reader :override_name, :accessor_name, :column

      def initialize(override_name, accessor_name, column)
        @override_name = override_name
        @accessor_name = accessor_name
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
