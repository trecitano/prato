# frozen_string_literal: true

module Prato
  module Types
    class Column
      attr_reader :arel_node, :format, :association_path

      def initialize(accessor, format: nil)
        @accessor = accessor
        @format = format
      end

      def resolve_arel!(base_model, display_id)
        @sql_alias = display_id.to_s

        if @accessor.is_a?(Array) && @accessor.length > 1
          @association_path = @accessor[0..-2]

          seen_tables = {}
          current_model = base_model
          current_table_name = base_model.table_name
          terminal_table = nil

          @association_path.each do |assoc_name|
            reflection = current_model.reflect_on_association(assoc_name)
            table_name = reflection.klass.table_name

            if seen_tables[table_name]
              aliased_name = reflection.alias_candidate(current_table_name)
              terminal_table = reflection.klass.arel_table.alias(aliased_name)
            else
              seen_tables[table_name] = true
              terminal_table = reflection.klass.arel_table
            end

            current_table_name = table_name
            current_model = reflection.klass
          end

          @arel_node = terminal_table[@accessor[-1]]
        else
          attr_name = @accessor.is_a?(Array) ? @accessor.first : @accessor
          @arel_node = base_model.arel_table[attr_name]
        end
      end

      def extract_value(record, _)
        record[@sql_alias]
      end

      private

      def build_on_condition(reflection, source_table, target_table)
        if reflection.macro == :belongs_to
          source_table[reflection.foreign_key].eq(
            target_table[reflection.active_record_primary_key]
          )
        else
          target_table[reflection.foreign_key].eq(
            source_table[reflection.active_record_primary_key]
          )
        end
      end
    end
  end
end
