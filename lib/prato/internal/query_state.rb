# frozen_string_literal: true

module Prato
  module Internal
    class QueryState
      attr_reader :dataset

      def self.create(base_scope)
        dataset = base_scope.dup

        new(dataset, nil)
      end

      def with_dataset(dataset)
        self.class.new(dataset, @ruby_loaded_data)
      end

      def unmaterialized?
        !dataset.is_a?(Array)
      end

      def materialized_dataset(spec, display_fields)
        return [@dataset, @ruby_loaded_data] unless unmaterialized?

        columns = spec.columns
        scope = dataset
        selects = Set.new([Arel.sql("#{scope.model.table_name}.*")])
        association_paths = []

        display_fields.each do |field|
          column = columns[field]

          case column
          when Types::AggregateColumn, Types::ExpressionColumn
            selects << column.select_node
          when Types::AssociationColumn
            association_paths << column.association_path
          end
        end

        if association_paths.any?
          includes = build_associations(association_paths.uniq)
          scope = scope.includes(includes)
        end

        scope = scope.select(selects.to_a)
        records = scope.to_a

        ruby_loaded_data = nil
        if spec.ruby_loaders&.any?
          ruby_loaded_data = LazyLoaderCache.new(records)
          spec.ruby_loaders.each { |key, block| ruby_loaded_data[key] = block }
        end

        @records = records
        @ruby_loaded_data = ruby_loaded_data
        [records, ruby_loaded_data]
      end

      private

      def build_associations(paths)
        result = {}

        paths.each do |path|
          next if path.empty?

          current = result
          path.each do |assoc|
            current[assoc] ||= {}
            current = current[assoc]
          end
        end

        result
      end

      def initialize(dataset, ruby_loaded_data)
        @dataset = dataset
        @ruby_loaded_data = ruby_loaded_data
      end
    end
  end
end
