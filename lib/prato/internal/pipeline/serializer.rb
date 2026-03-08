# frozen_string_literal: true

module Prato
  module Internal
    module Pipeline
      module Serializer
        extend self

        def serialize_query(query_state, spec, raw_fields)
          records, ruby_loaded_data = query_state.materialized_dataset(spec)
          fields = raw_fields || spec.all_fields
          columns = spec.columns

          inner_serialize(fields, records, ruby_loaded_data, columns)
        end

        private

        def inner_serialize(fields, records, ruby_loaded_data, columns)
          records.map do |record|
            serialize_record(fields, record, ruby_loaded_data, columns)
          end
        end

        def serialize_record(fields, record, ruby_loaded_data, columns)
          record.each_with_object({}) do |record, hash|
            fields.each do |field|
              column = columns[field]

              result = if column.is_a?(Types::Section)
                         serialize_record(column.columns, record, ruby_loaded_data)
                       elsif column.is_a?(Types::RubyColumn)
                         ValueExtractor.extract_computed_value(record, column, ruby_loaded_data)
                       elsif column.display
                         column.display.call(record)
                       else
                         ValueExtractor.extract_value_with_accessor(record, column.acessor)
                       end

              hash[field] = result
            end
          end
        end
      end
    end
  end
end
