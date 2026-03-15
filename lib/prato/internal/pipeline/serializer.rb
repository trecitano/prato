# frozen_string_literal: true

module Prato
  module Internal
    module Pipeline
      module Serializer
        module_function

        def serialize_query(query_state, spec, raw_fields)
          fields = raw_fields || spec.all_fields
          records, ruby_loaded_data = query_state.materialized_dataset(spec, fields)
          columns = spec.columns

          records.map do |record|
            fields.each_with_object({}).each do |field, hash|
              column = columns[field]

              value = if column.is_a?(Types::RubyColumn)
                        column.extract_value(record, ruby_loaded_data)
                      else
                        value = column.extract_value(record, nil)
                        column.format ? column.format.call(value) : value
                      end

              assign_field(hash, field, value)
            end
          end
        end

        private

        def assign_field(result_set, field, value)
          current = result_set
          field[0...-1].each do |key|
            current[key] ||= {}
            current = current[key]
          end
          current[field.last] = value
        end
      end
    end
  end
end
