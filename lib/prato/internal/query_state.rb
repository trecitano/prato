# frozen_string_literal: true

module Prato
  module Internal
    class QueryState
      attr_reader :dataset

      def self.create(base_scope, materialization_fields)
        dataset = base_scope.dup

        new(dataset, nil, materialization_fields)
      end

      def with_dataset(dataset)
        self.class.new(dataset, @ruby_loaded_data, @materialization_fields)
      end

      def unmaterialized?
        !dataset.is_a?(Array)
      end

      def materialized_dataset(spec)
        return [@dataset, @ruby_loaded_data] unless unmaterialized?

        columns = spec.columns
        scope = dataset
        selects = Set.new([Arel.sql("#{scope.model.table_name}.*")])
        includes_values = []

        @materialization_fields.each do |field|
          column = columns[field]

          case column
          when Types::AggregateColumn, Types::ExpressionColumn
            selects << column.select_node
          when Types::AssociationColumn
            includes_values << association_path_to_includes(column.association_path)
          when Types::RubyColumn
            includes_values << column.includes if column.includes

            loader = spec.ruby_loaders&.[](column.loader)
            includes_values << loader[:includes] if loader && loader[:includes]
          end
        end

        if includes_values.any?
          scope = scope.includes(*includes_values)
        end

        scope = scope.select(selects.to_a)
        records = scope.to_a

        ruby_loaded_data = nil
        if spec.ruby_loaders&.any?
          ruby_loaded_data = LazyLoaderCache.new(records)
          spec.ruby_loaders.each { |key, loader| ruby_loaded_data[key] = loader[:block] }
        end

        @records = records
        @ruby_loaded_data = ruby_loaded_data
        [records, ruby_loaded_data]
      end

      private

      def association_path_to_includes(path)
        head, *tail = path
        return head if tail.empty?

        { head => association_path_to_includes(tail) }
      end

      def initialize(dataset, ruby_loaded_data, materialization_fields)
        @dataset = dataset
        @ruby_loaded_data = ruby_loaded_data
        @materialization_fields = materialization_fields
      end
    end
  end
end
