# frozen_string_literal: true

module Prato
  module Internal
    class Specification
      attr_reader :columns, :context, :config

      def initialize
        @columns = {}
        @config = Prato::Configuration.config
        @validated = false
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

        id, accessor = parse_name_map(name_map)
        col = ::Prato::Types::Column.new(id, accessor, display: display, scope: scope)

        @columns[id] = col
        @validated = false
      end

      def inner_ruby_column(*args, **kwargs)
        if args.any?
          name_map = args.first
          key = kwargs[:key]
        else
          key = kwargs.delete(:key)
          name_map = kwargs
        end

        id, source = parse_name_map(name_map)
        accessor = parse_accessor(key)
        col = ::Prato::Types::RubyColumn.new(id, source: source, key: accessor)

        add_column_and_invalidate(id, col)

        @columns[id] = col
        @validated = false
      end

      def inner_section(id, &block)
        nested_spec = ::Prato::Internal::Specification.new

        block.call(nested_spec) if block_given?

        group = ::Prato::Types::Section.new(id, nested_spec)

        @columns[id] = group
        @validated = false
      end

      def inner_context(context)
        @context = context
        @validated = false
      end

      def inner_config(config)
        @config = config
        @validated = false
      end

      def validate_and_update_keys!
        return if @validated

        columns.each do |id, col|

        end

      end

      def all_fields
        @all_fields ||= extract_fields(columns)
      end

      private

      def add_column_and_invalidate(id, column)
        @validated = false
        @all_fields = nil

        @columns[id] = column
      end

      # Given a list of columns, returns an array of either symbols or arrays of symbols
      def extract_fields(columns)
        columns.map do |col|
          if col.is_a?(Types::Section)
            extract_fields(col.columns)
          else
            col.id
          end
        end
      end

      def parse_name_map(name_map)
        case name_map
        when Symbol
          [name_map, name_map]
        when Hash
          raise ArgumentError, "name_map hash must have exactly one key" unless name_map.size == 1

          id, value = name_map.first
          accessor = parse_accessor(value)
          [id, accessor]
        when nil
          raise ArgumentError, "name_map cannot be nil"
        else
          raise ArgumentError, "name_map must be a Symbol or Hash"
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
    end
  end
end
