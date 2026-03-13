# frozen_string_literal: true

module Prato
  module Internal
    module Pipeline
      module Serializer
        module_function

        def serialize_query(query_state, spec, raw_fields)
          records, ruby_loaded_data = query_state.materialized_dataset(spec)
          fields = raw_fields || spec.all_fields
          columns = spec.columns

          records.map do |record|
            fields.each_with_object({}).each do |field, hash|
              column = columns[field]

              result = if column.is_a?(Types::RubyColumn)
                         column.extract_value(record, ruby_loaded_data)
                       elsif column.is_a?(Types::Column) && column.display
                         column.display.call(record)
                       else
                         column.extract_value(record, nil)
                       end

              hash[field] = result
            end
          end
        end
      end
    end
  end
end
