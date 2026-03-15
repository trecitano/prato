# frozen_string_literal: true

module Prato
  module Types
    class Column
      attr_reader :arel_node, :format

      def initialize(accessor, format: nil)
        @accessor = accessor
        @format = format
      end

      def resolve_arel!(base_model, display_id)
        @sql_alias = display_id.is_a?(Array) ? display_id.join("__") : display_id.to_s

        if @accessor.is_a?(Array) && @accessor.length > 1
          association_path = @accessor[0..-2]
          target_model = association_path.reduce(base_model) do |model, assoc|
            model.reflect_on_association(assoc).klass
          end
          @arel_node = target_model.arel_table[@accessor[-1]]
        else
          attr_name = @accessor.is_a?(Array) ? @accessor.first : @accessor
          @arel_node = base_model.arel_table[attr_name]
        end
      end

      def extract_value(record, _)
        record[@sql_alias]
      end
    end
  end
end
