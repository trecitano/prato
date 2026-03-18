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
      COMMON_RESERVED_KEYWORDS = %i[only except].freeze
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
          draft = if nested.override_name.nil?
                    DraftColumn.new(nil, Query::FieldPath.from([id, nested.accessor_name]), nested.column, only: nested.only, except: nested.except)
                  else
                    DraftColumn.new(Query::FieldPath.from([id, nested.accessor_name]), nil, nested.column, only: nested.only, except: nested.except)
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
          column_display_id = transform_draft_name(draft)
          validate_ruby_loader!(draft, @ruby_loaders) unless draft.query_only

          if columns.key?(column_display_id)
            raise ArgumentError, "Column '#{column_display_id}' has already been defined."
          end

          column = draft.column

          if column.is_a?(Types::Column) || column.is_a?(Types::ExpressionColumn) || column.is_a?(Types::AggregateColumn)
            column.resolve_arel!(base_model, column_display_id)
          end

          filterable = resolve_capability(:filter, draft)
          sortable = resolve_capability(:sort, draft)

          if draft.query_only && !filterable && !sortable
            raise ArgumentError, "query_column '#{column_display_id}' must be filterable or sortable"
          end

          columns[column_display_id] = column
          visible_fields << column_display_id unless draft.query_only
          filterable_fields << column_display_id if filterable
          sortable_fields << column_display_id if sortable
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
        default = capability == :filter ? @config.default_filterable : @config.default_sortable
        if draft.only
          Array(draft.only).include?(capability)
        elsif draft.except
          !Array(draft.except).include?(capability)
        else
          default
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

      def build_draft(args, kwargs, query_only: false)
        only = kwargs.delete(:only)
        except = kwargs.delete(:except)

        if only && except
          raise ArgumentError, "Cannot specify both only: and except: on the same column"
        end

        name_map, options = extract_name_and_options(args, kwargs, RESERVED_COLUMN_SYMBOLS)
        aggregate_function, aggregate_accessor = extract_aggregate(options)

        if aggregate_function
          column = ::Prato::Types::AggregateColumn.new(aggregate_function, aggregate_accessor, format: options[:format])
          DraftColumn.new(nil, name_map, column, only: only, except: except, query_only: query_only)
        elsif options[:expression]
          name, accessor = parse_name_map(name_map)
          column = ::Prato::Types::ExpressionColumn.new(options[:expression], format: options[:format])
          DraftColumn.new(name, accessor, column, only: only, except: except, query_only: query_only)
        else
          name, accessor = parse_name_map(name_map)
          column = ::Prato::Types::Column.new(accessor, format: options[:format])
          DraftColumn.new(name, accessor, column, only: only, except: except, query_only: query_only)
        end
      end

      def extract_name_and_options(args, kwargs, reserved)
        if args.any?
          [args.first, kwargs]
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

      def transform_draft_name(draft)
        (draft.override_name || draft.accessor_name).to_sym
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
    end

    class DraftColumn
      attr_reader :override_name, :accessor_name, :column, :only, :except, :query_only

      def initialize(override_name, accessor_name, column, only: nil, except: nil, query_only: false)
        @override_name = override_name
        @accessor_name = accessor_name
        @column = column
        @only = only
        @except = except
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
