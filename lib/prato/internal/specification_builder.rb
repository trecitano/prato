# frozen_string_literal: true

module Prato
  module Internal
    class SpecificationBuilder

      attr_reader :draft_columns

      def initialize
        @config = Prato::Configuration.config
        @draft_columns = []
        @ruby_loaders = nil
      end

      AGGREGATE_FUNCTIONS = %i[count sum avg min max].freeze
      COMMON_RESERVED_KEYWORDS = %i[only].freeze
      RESERVED_COLUMN_SYMBOLS = (%i[format expression] + COMMON_RESERVED_KEYWORDS + AGGREGATE_FUNCTIONS).freeze
      RESERVED_RUBY_COLUMN_SYMBOLS = (%i[loader key] + COMMON_RESERVED_KEYWORDS).freeze

      def inner_column(*args, **kwargs)
        draft = build_draft(args, kwargs)
        @draft_columns << draft
      end

      def inner_query_column(*args, **kwargs)
        draft = build_draft(args, kwargs, query_only: true)
        @draft_columns << draft
      end

      def inner_ruby_column(*args, **kwargs)
        name_map, = extract_name_and_options(args, kwargs, RESERVED_RUBY_COLUMN_SYMBOLS)
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
          joined_name = Prato::Query::FieldPath.from([id, nested.accessor_name])
          draft = if nested.override_name.nil?
                    DraftColumn.new(nil, joined_name, nested.column, only: nested.only)
                  else
                    DraftColumn.new(joined_name, nil, nested.column, only: nested.only)
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

      def build(base_model)
        columns = {}
        visible_fields = []
        filterable_fields = Set.new
        sortable_fields = Set.new

        @draft_columns.each do |draft|
          raw_column_name = raw_column_name(draft)
          internal_column_name = raw_column_name.to_s.tr(" ", "_").delete("^A-Za-z0-9_")

          if columns.key?(internal_column_name)
            raise ArgumentError, "Column '#{raw_column_name}' has already been defined."
          end

          column = draft.column

          if column.is_a?(Types::Column) || column.is_a?(Types::ExpressionColumn) || column.is_a?(Types::AggregateColumn)
            column.resolve_arel!(base_model, internal_column_name)
          end

          filterable = resolve_capability(:filter, draft)
          sortable = resolve_capability(:sort, draft)

          columns[internal_column_name] = column
          visible_fields << internal_column_name unless draft.query_only
          filterable_fields << internal_column_name if filterable
          sortable_fields << internal_column_name if sortable
        end

        output_paths = {}
        columns.each_key do |key|
          parts = key.to_s.split("__")
          output_paths[key] = parts.map { |part| transform_key_part(part, @config.key_transformation).to_sym }
        end

        Specification.new(
          columns: columns,
          visible_fields: visible_fields,
          filterable_fields: filterable_fields,
          sortable_fields: sortable_fields,
          output_paths: output_paths,
          ruby_loaders: @ruby_loaders,
          config: @config
        )
      end

      private

      def resolve_capability(capability, draft)
        only = draft.only || (draft.query_only ? nil : @config.default_only)

        if only
          only == capability
        else
          true
        end
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

      VALID_COLUMN_ONLY = %i[display filter sort].freeze
      VALID_QUERY_COLUMN_ONLY = %i[filter sort].freeze

      def build_draft(args, kwargs, query_only: false)
        only = kwargs.delete(:only)

        if only
          raise ArgumentError, "only: must be a Symbol, got #{only.class}" unless only.is_a?(Symbol)

          valid = query_only ? VALID_QUERY_COLUMN_ONLY : VALID_COLUMN_ONLY
          unless valid.include?(only)
            raise ArgumentError, "only: must be one of #{valid.map(&:inspect).join(", ")}, got #{only.inspect}"
          end
        end

        name_map, options = extract_name_and_options(args, kwargs, RESERVED_COLUMN_SYMBOLS)
        aggregate_function, aggregate_accessor = extract_aggregate(options)
        override_name, accessor = parse_name_map(name_map)

        if aggregate_function
          column = ::Prato::Types::AggregateColumn.new(aggregate_function, aggregate_accessor, format: options[:format])
          DraftColumn.new(override_name, nil, column, only: only, query_only: query_only)
        elsif options[:expression]
          column = ::Prato::Types::ExpressionColumn.new(options[:expression], format: options[:format])
          DraftColumn.new(override_name, accessor, column, only: only, query_only: query_only)
        else
          column = ::Prato::Types::Column.new(accessor, format: options[:format])
          DraftColumn.new(override_name, accessor, column, only: only, query_only: query_only)
        end
      end

      def extract_name_and_options(args, kwargs, reserved)
        if args.any?
          [args, kwargs]
        else
          option_keys = kwargs.keys & reserved
          options = kwargs.slice(*option_keys)
          name_map = kwargs.except(*reserved)
          [name_map, options]
        end
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
        when Symbol
          [nil, name_map]
        when Array
          if name_map.size == 2
            [name_map.first, name_map.second]
          else
            [nil, name_map.first]
          end
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

      def raw_column_name(draft)
        (draft.override_name || draft.accessor_name)
      end

      def transform_key_part(part, transformation)
        case transformation
        when :camelCase then to_camel_case(part)
        when :snake_case then to_snake_case(part)
        when :none then part
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
      private_constant :COMMON_RESERVED_KEYWORDS
      private_constant :AGGREGATE_FUNCTIONS
      private_constant :VALID_COLUMN_ONLY
      private_constant :VALID_QUERY_COLUMN_ONLY
    end

    class DraftColumn
      attr_reader :override_name, :accessor_name, :column, :only, :query_only

      def initialize(override_name, accessor_name, column, only: nil, query_only: false)
        @override_name = override_name
        @accessor_name = accessor_name
        @column = column
        @only = only
        @query_only = query_only
      end
    end

    class SectionBuilder
      attr_reader :spec

      def initialize
        @spec = SpecificationBuilder.new
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
