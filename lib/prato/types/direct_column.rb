# frozen_string_literal: true

module Prato
  module Types
    class DirectColumn
      attr_reader :format, :filter

      def initialize(accessor, format: nil, filter: nil)
        @attribute_name = accessor.is_a?(Array) ? accessor.first : accessor
        @format = format
        @filter = filter
      end

      def resolve_arel!(base_model, _display_id)
        @arel_node = base_model.arel_table[@attribute_name]
      end

      def sql_node_for(_scope)
        @arel_node
      end

      def extract_value(record, _ruby_data)
        record[@attribute_name]
      end
    end
  end
end
