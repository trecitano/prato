# frozen_string_literal: true

module Prato
  module Internal
    module Pipeline
      module Serializer
        extend self

        def serialize_query(query_state, spec, raw_fields)
          fields = raw_fields || spec.visible_fields

          if query_state.unmaterialized? && spec.sql_only?(fields)
            optimized_serialization(query_state, spec, fields)
          else
            normal_serialization(query_state, spec, fields)
          end
        end

        private

        def optimized_serialization(query_state, spec, fields)
          columns = spec.columns
          scope = query_state.dataset
          association_paths = []

          fields.each do |field|
            column = columns[field]
            association_paths << column.association_path if column.is_a?(Types::AssociationColumn)
          end

          scope = Internal::JoinHelper.ensure_left_joins(scope, association_paths.uniq)

          selects = fields.map do |field|
            column = columns[field]

            case column
            when Types::DirectColumn, Types::AssociationColumn, Types::AggregateColumn, Types::ExpressionColumn
              column.sql_node_for(scope)
            else
              raise "Assertion error: Trying to serialize with unknown column type: #{column.class}"
            end
          end

          rows = scope.pluck(*selects)

          rows.map do |data|
            fields.each_with_object({}).with_index do |(field, hash), idx|
              column = columns[field]

              value = Array(data)[idx]
              value = column.format.call(value) if column.format

              assign_value(hash, spec, field, value)
            end
          end
        end

        def normal_serialization(query_state, spec, fields)
          records, ruby_loaded_data = query_state.materialized_dataset(spec, fields)
          columns = spec.columns

          records.map do |record|
            fields.each_with_object({}) do |field, hash|
              column = columns[field]

              value = if column.is_a?(Types::RubyColumn)
                        column.extract_value(record, ruby_loaded_data)
                      else
                        value = column.extract_value(record, nil)
                        column.format ? column.format.call(value) : value
                      end

              assign_value(hash, spec, field, value)
            end
          end
        end

        def assign_value(hash, spec, field, value)
          output_path = spec.field_mapping(field)
          current = hash
          output_path[0..-2].each { |key| current = (current[key] ||= {}) }
          current[output_path.last] = value
        end
      end
    end
  end
end
