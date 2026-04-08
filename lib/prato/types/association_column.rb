# frozen_string_literal: true

module Prato
  module Types
    class AssociationColumn
      attr_reader :association_path, :format, :filter

      def initialize(accessor, format: nil, filter: nil)
        @association_path = accessor[0..-2].map(&:to_sym).freeze
        @attribute_name = accessor[-1].to_sym
        @format = format
        @filter = filter
      end

      def resolve_arel!(base_model, _display_id)
        current_model = base_model

        @association_path.each do |assoc_name|
          reflection = current_model.reflect_on_association(assoc_name)
          raise ArgumentError, "Unknown association '#{assoc_name}' on #{current_model}" unless reflection

          current_model = reflection.klass
        end
      end

      def sql_node_for(scope)
        table = Internal::SqlSupport.table_for(scope, @association_path)
        table[@attribute_name]
      end

      def extract_value(record, _ruby_data)
        target = @association_path.reduce(record) { |obj, assoc| obj&.public_send(assoc) }
        target&.[](@attribute_name)
      end
    end
  end
end
