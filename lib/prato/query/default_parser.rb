# frozen_string_literal: true

require "json"

module Prato
  module Query
    class DefaultParser

      def parse_parameters(input)
        parsed_hash = normalize_to_hash(input)
        normalized_hash = normalize_hash_keys(parsed_hash)

        Prato::Query::Parameters.new(
          page: parse_page(normalized_hash[:page]),
          per_page: parse_per_page(normalized_hash[:per_page]),
          filters: parse_filters(normalized_hash[:filters]),
          sorts: parse_sorts(normalized_hash[:sorts]),
          fields: parse_fields(normalized_hash[:fields])
        )
      end

      def parse_page(raw_value)
        value = raw_value&.to_i || 1
        value.positive? ? value : 1
      end

      def parse_per_page(raw_value)
        raw_value&.to_i
      end

      def parse_filters(input)
        return nil if input.nil?

        case input
        when Prato::Query::AndFilter
          input
        when Prato::Query::OrFilter, Prato::Query::Filter
          Prato::Query::AndFilter.new([input])
        when Hash
          Prato::Query::AndFilter.new([parse_filter_entry(input)])
        when Array
          filters = input.map { |entry| parse_filter_entry(entry) }
          filters.empty? ? nil : Prato::Query::AndFilter.new(filters)
        else
          raise ArgumentError, "Invalid filters type: #{input.class}"
        end
      end

      def parse_filter_entry(entry)
        return entry if entry.is_a?(Prato::Query::Filter) ||
                        entry.is_a?(Prato::Query::AndFilter) ||
                        entry.is_a?(Prato::Query::OrFilter)

        filter_hash = normalize_hash_keys(coerce_hash(entry, context: "filter"))

        if filter_hash.key?(:or)
          nested = array_wrap(filter_hash[:or]).map { |nested_entry| parse_filter_entry(nested_entry) }
          Prato::Query::OrFilter.new(nested)
        elsif filter_hash.key?(:and)
          nested = array_wrap(filter_hash[:and]).map { |nested_entry| parse_filter_entry(nested_entry) }
          Prato::Query::AndFilter.new(nested)
        else
          field = filter_hash[:field]
          operator = filter_hash[:operator]
          raise ArgumentError, "Each filter must include :field and :operator." if field.nil? || operator.nil?

          Prato::Query::Filter.new(parse_field(field), operator.to_sym, filter_hash[:value])
        end
      end

      # Converts field string to symbol or array of symbols
      # "status" -> :status
      # "bankAccount.branchBankAccountId" -> [:bankAccount, :branchBankAccountId]
      def parse_field(field)
        case field
        when Symbol
          field
        when String
          parts = field.split('.')
          parts.length == 1 ? parts.first.to_sym : parts.map(&:to_sym)
        when Array
          symbols = field.map do |part|
            unless part.respond_to?(:to_sym)
              raise ArgumentError,
                    "Field path parts must be symbols or strings. Got: #{part.class}"
            end

            part.to_sym
          end

          symbols.length == 1 ? symbols.first : symbols
        else
          raise ArgumentError, "Invalid field value: #{field.inspect}"
        end
      end

      def parse_sorts(input)
        return nil if input.nil?

        case input
        when String
          parse_sorts(parse_json_value(input, context: 'sorts'))
        when Prato::Query::Sort
          [input]
        when Hash
          [parse_sort_entry(input)]
        when Array
          input.map { |entry| parse_sort_entry(entry) }
        else
          raise ArgumentError, "Invalid sorts type: #{input.class}"
        end
      end

      def parse_sort_entry(entry)
        return entry if entry.is_a?(Prato::Query::Sort)

        sort_hash = normalize_entry_hash(entry, context: 'sort')
        field = sort_hash[:field]
        raise ArgumentError, 'Each sort must include :field.' if field.nil?

        direction = if sort_hash.key?(:direction)
                      normalize_sort_direction(sort_hash[:direction])
                    else
                      truthy?(sort_hash[:desc]) ? :desc : :asc
                    end

        Prato::Query::Sort.new(parse_field(field), direction)
      end

      def parse_fields(fields)
        return nil if fields.nil?
      end

      private

      def array_wrap(value)
        return [] if value.nil?
        return value if value.is_a?(Array)

        [value]
      end

      def normalize_to_hash(input)
        case input
        when nil
          {}
        when String
          parsed = parse_json(input, context: "table params")
          raise ArgumentError, "Expected table params JSON to decode to an object." unless parsed.is_a?(Hash)

          parsed
        else
          input
        end
      end

      def normalize_hash_keys(hash)
        hash.each_with_object({}) do |(key, value), result|
          result[key.respond_to?(:to_sym) ? key.to_sym : key] = value
        end
      end

      def coerce_hash(value, context: nil)
        case value
        when Hash
          value
        when String
          parse_json_value(value, context: context)
        else
          raise ArgumentError, "Expected a Hash for #{context}, got #{value.class}"
        end
      end

      def normalize_entry_hash(entry, context: nil)
        normalize_hash_keys(coerce_hash(entry, context: context))
      end

      def normalize_sort_direction(value)
        case value.to_s.downcase
        when "desc", "descending"
          :desc
        else
          :asc
        end
      end

      def truthy?(value)
        case value
        when true, 1, "1", "true", "yes"
          true
        else
          false
        end
      end

      def parse_json(string, context: nil)
        JSON.parse(string)
      rescue JSON::ParserError => e
        raise ArgumentError, "Invalid JSON for #{context}: #{e.message}"
      end

      def parse_json_value(string, context: nil)
        parse_json(string, context: context)
      end
    end
  end
end
