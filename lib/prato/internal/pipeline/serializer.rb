# frozen_string_literal: true

module Prato
  module Internal
    module Pipeline
      module Serializer
        module_function

        def serialize_query(query_state, spec, raw_fields)
          fields = raw_fields || spec.visible_fields
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

              output_path = spec.field_mapping(field)
              current = hash
              output_path[0..-2].each { |key| current = (current[key] ||= {}) }
              current[output_path.last] = value
            end
          end
        end
      end
    end
  end
end
