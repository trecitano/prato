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

              result = if column.is_a?(Types::RubyColumn)
                         column.extract_value(record, ruby_loaded_data)
                       elsif column.respond_to?(:transform_record) && column.transform_record
                         column.transform_record.call(record)
                       else
                         value = column.extract_value(record, nil)
                         column.format ? column.format.call(value) : value
                       end

              hash[field] = result
            end
          end
        end
      end
    end
  end
end
