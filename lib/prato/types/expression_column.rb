# frozen_string_literal: true

module Prato
  module Types
    class ExpressionColumn
      attr_reader :arel_node, :format

      def initialize(expression, format: nil)
        @expression = expression
        @format = format
      end

      def resolve_arel!(base_model, display_id)
        expression_sql = if @expression.is_a?(Symbol)
                           base_model.public_send(@expression)
                         else
                           @expression
                         end

        @sql_alias = display_id.to_s
        @arel_node = Arel::Nodes::Grouping.new(Arel.sql(expression_sql))
      end

      def select_node
        @arel_node.as(@sql_alias)
      end

      def extract_value(record, _)
        record[@sql_alias]
      end
    end
  end
end
