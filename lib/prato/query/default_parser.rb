# frozen_string_literal: true

require "json"

module Prato
  module Query
    class DefaultParser
      def parse_parameters(input, context)
        Prato::Query::Parameters.new(
          page: parse_page(input["page"], context),
          per_page: parse_per_page(input["per_page"], context),
          filters: parse_filters(input["filters"], context),
          sorts: parse_sorts(input["sorts"], context),
          fields: parse_fields(input["fields"], context)
        )
      end

      def parse_page(raw_value)
        safe_parse_integer(raw_value)
      end

      def parse_per_page(raw_value)
        safe_parse_integer(raw_value)
      end

      def parse_filters(input, context)
        return nil if input.nil?

        entries = normalize_entries_to_hash(input)
        parse_filter_entries(entries, context)
      end

      def parse_filter_entries(entries, context, depth = 0)
        if depth == 10
          raise ArgumentError, "Filter nesting too deep (maximum depth: 10)"
        end

        Array(entries).map do |entry|
          if entry.key?("or")
            nested = parse_filter_entries(entry["or"], context, depth + 1)
            return nil if nested.empty?

            Prato::Query::OrFilter.new(nested)
          elsif entry.key?("and")
            nested = parse_filter_entries(entry["and"], context, depth + 1)
            return nil if nested.empty?

            Prato::Query::AndFilter.new(nested)
          else
            field = entry["field"]
            operator = entry["operator"]
            value = entry["value"]

            Prato::Query::Filter.new(
              parse_field(field, context),
              operator.to_sym,
              value
            )
          end
        end
      end

      def parse_sorts(input, context)
        return nil if input.nil?

        entries = normalize_entries_to_hash(input)

        Array(entries).map do |entry|
          field = entry["field"]
          order = entry["order"]

          Prato::Query::Sort.new(parse_field(field, context), order)
        end
      end

      def parse_fields(input, context)
        return nil if input.nil?

        entries = normalize_entries_to_hash(input)

        Array(entries).map do |entry|
          parse_field(entry, context)
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
    end
  end
end
