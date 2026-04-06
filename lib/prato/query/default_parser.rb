# frozen_string_literal: true

require "json"

module Prato
  module Query
    class DefaultParser
      def parse_parameters(input, field_lookup)
        page = hash_access(input, "page")
        per_page = hash_access(input, "per_page")
        filters = hash_access(input, "filters")
        sorts = hash_access(input, "sorts")
        fields = hash_access(input, "fields")

        Prato::Query::Parameters.new(
          page: parse_page(page),
          per_page: parse_per_page(per_page),
          filters: parse_filters(filters, field_lookup),
          sorts: parse_sorts(sorts, field_lookup),
          fields: parse_fields(fields, field_lookup)
        )
      end

      def parse_page(raw_value)
        safe_parse_integer(raw_value)
      end

      def parse_per_page(raw_value)
        safe_parse_integer(raw_value)
      end

      def parse_filters(input, field_lookup)
        return nil if input.nil?

        entries = normalize_entries_to_hash(input)
        filters = parse_filter_entries(entries, field_lookup)
        filters.nil? || filters.empty? ? nil : filters
      end

      def parse_filter_entries(entries, field_lookup, depth = 0)
        raise ArgumentError, "Filter nesting too deep (maximum depth: 10)" if depth == 10

        Array.wrap(entries).map do |entry|
          if hash_access(entry, "or")
            nested = parse_filter_entries(hash_access(entry, "or"), field_lookup, depth + 1)
            next if nested.nil? || nested.empty?

            Prato::Query::OrFilter.new(nested)
          elsif hash_access(entry, "and")
            nested = parse_filter_entries(hash_access(entry, "and"), field_lookup, depth + 1)
            next if nested.nil? || nested.empty?

            Prato::Query::AndFilter.new(nested)
          else
            field = hash_access(entry, "field")
            operator = hash_access(entry, "operator")
            value = hash_access(entry, "value")

            Prato::Query::Filter.new(
              parse_field(field, field_lookup),
              operator.to_sym,
              value
            )
          end
        end.compact
      end

      def parse_sorts(input, field_lookup)
        return nil if input.nil?

        entries = normalize_entries_to_hash(input)

        Array.wrap(entries).map do |entry|
          field = hash_access(entry, "field")
          order = hash_access(entry, "order")
          is_desc = %w[desc descending].include?(order)

          Prato::Query::Sort.new(parse_field(field, field_lookup), is_desc)
        end
      end

      def parse_fields(input, field_lookup)
        return nil if input.nil?

        entries = normalize_entries_to_hash(input)

        Array.wrap(entries).map do |entry|
          parse_field(entry, field_lookup)
        end
      end

      protected

      def parse_field(field, field_resolver)
        fields = field.split(".")
        field_resolver.call(fields)
      end

      def safe_parse_integer(number)
        return nil if number.nil?

        begin
          Integer(number)
        rescue ArgumentError
          nil
        end
      end

      def normalize_entries_to_hash(input)
        case input
        when String
          JSON.parse(input)
        when Array, Hash
          input
        else
          raise ArgumentError, "Invalid filters type: #{input.class}"
        end
      end

      def hash_access(entry, key)
        value = entry[key]
        if value.nil?
           entry[key.to_sym]
        else
          value
        end
      end
    end
  end
end
