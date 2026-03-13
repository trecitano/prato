# frozen_string_literal: true

module Prato
  module Types
    class Column
      attr_reader :accessor, :display, :scope, :association_path, :arel_node, :aggregate_field

      def initialize(accessor, display: nil, scope: nil)
        @accessor = accessor
        @display = display
        @scope = scope
      end

      def resolve_arel!(base_model)
        if accessor.is_a?(Array) && accessor.length > 1
          @association_path = accessor[0..-2]
          target_model = @association_path.reduce(base_model) do |model, assoc|
            model.reflect_on_association(assoc).klass
          end
          @arel_node = target_model.arel_table[accessor[-1]]
        else
          attr_name = accessor.is_a?(Array) ? accessor.first : accessor
          @arel_node = base_model.arel_table[attr_name]
          @association_path = nil
        end
      end

      def extract_value(record, _)
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
    end
  end
end
