# frozen_string_literal: true

module Prato
  module Types
    class AggregateColumn
      attr_reader :arel_node, :format

      def initialize(aggregate_function, aggregate_accessor, format: nil)
        @accessor = Array(aggregate_accessor)
        @aggregate_function = aggregate_function
        @format = format
      end

      def resolve_arel!(base_model, display_id)
        association_path = @aggregate_function == :count ? @accessor : @accessor[0..-2]
        aggregate_field = @aggregate_function == :count ? nil : @accessor[-1]

        reflections = resolve_reflections(base_model, association_path)
        base_table = base_model.arel_table
        aliased_tables = reflections.each_with_index.map do |reflection, index|
          Arel::Table.new(reflection.klass.table_name, as: "prato_agg_#{index}_#{reflection.klass.table_name}")
        end
        target_table = aliased_tables.last

        subquery = target_table.project(aggregate_expression(target_table, @aggregate_function, aggregate_field))

        (reflections.length - 1).downto(1) do |i|
          ref = reflections[i]
          source_table = aliased_tables[i - 1]
          subquery = subquery.join(source_table).on(
            association_condition(ref, source_table, aliased_tables[i])
          )
        end

        first_ref = reflections.first
        subquery = subquery.where(
          association_condition(first_ref, base_table, aliased_tables.first)
        )

        @arel_node = Arel::Nodes::Grouping.new(subquery)
        @sql_alias = display_id.to_s
      end

      def sql_node_for(_scope)
        @arel_node
      end

      def select_node
        @arel_node.as(@sql_alias)
      end

      def extract_value(record, _)
        record[@sql_alias]
      end

      private

      def resolve_reflections(base_model, path)
        current_model = base_model
        path.map do |assoc_name|
          reflection = current_model.reflect_on_association(assoc_name)
          raise ArgumentError, "Unknown association '#{assoc_name}' on #{current_model}" unless reflection

          current_model = reflection.klass
          reflection
        end
      end

      def association_condition(reflection, source_table, target_table)
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

      def aggregate_expression(table, aggregate_function, aggregate_field)
        case aggregate_function
        when :count then Arel.star.count
        when :sum   then Arel::Nodes::NamedFunction.new("COALESCE", [table[aggregate_field].sum, 0])
        when :avg   then table[aggregate_field].average
        when :min   then table[aggregate_field].minimum
        when :max   then table[aggregate_field].maximum
        end
      end
    end
  end
end
