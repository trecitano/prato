# frozen_string_literal: true

module Prato
  module Internal
    module ValueExtractor
      extend self

      def extract_value(record, column, calculated_data)
        if column.type == :ruby
          extract_computed_value(record, column, calculated_data)
        else
          extract_value_with_accessor(record, column.accessor)
        end
      end

      def extract_value_with_accessor(record, accessor)
        case accessor
        when Array
          accessor.reduce(record) do |obj, method|
            return nil if obj.nil?

            obj.public_send(method)
          end
        when Symbol, String
          record.public_send(accessor)
        end
      end

      def extract_computed_value(record, column, context)
        computation_key = column.computation
        lookup_key_path = column.accessor
        key_value = extract_value_with_accessor(record, lookup_key_path)

        context[computation_key]&.[](key_value)
      end
    end
  end
end
