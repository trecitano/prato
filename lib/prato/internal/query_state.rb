# frozen_string_literal: true

module Prato
  module Internal
    class QueryState
      attr_reader :dataset, :ruby_loaders

      def self.create(base_scope)
        dataset = base_scope.dup
        ruby_loaders = {}

        new(dataset, ruby_loaders)
      end

      def with_dataset(dataset)
        self.class.new(dataset, ruby_loaders)
      end

      def unmaterialized?
        !dataset.is_a?(Array)
      end

      def materialized_dataset(spec, display_fields)
        return [dataset, @ruby_loaded_data] unless unmaterialized?

        if spec.sql_only?(display_fields)
          optimized_materialize(spec, display_fields)
        else
          full_materialize(spec, display_fields)
        end
      end

      def full_materialize(spec, display_fields)
        return [dataset, @ruby_loaded_data] unless unmaterialized?

        columns = spec.columns
        scope = dataset
        selects = Set.new([Arel.sql("#{scope.model.table_name}.*")])
        association_paths = []

        display_fields.each do |field|
          column = columns[field]

          case column
          when Types::AggregateColumn, Types::ExpressionColumn
            sql_alias = field.is_a?(Array) ? field.join("__") : field.to_s
            selects << column.arel_node.as(sql_alias)
          when Types::Column
            if column.association_path
              association_paths << column.association_path
            end
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

        @ruby_loaded_data = ruby_loaded_data
        [records, ruby_loaded_data]
      end

      private

      def optimized_materialize(spec, display_fields)
        columns = spec.columns
        scope = dataset
        selects = []
        aliases = []
        join_paths = []

        display_fields.each do |field|
          column = columns[field]
          sql_alias = field.is_a?(Array) ? field.join("__") : field.to_s

          case column
          when Types::AggregateColumn, Types::ExpressionColumn
            selects << column.arel_node.as(sql_alias)
            aliases << sql_alias
          when Types::Column
            if column.association_path
              join_paths << column.association_path
            end
            selects << column.arel_node.as(sql_alias)
            aliases << sql_alias
          end
        end

        if join_paths.any?
          joins = build_join_hash(join_paths.uniq)
          scope = scope.left_joins(*joins)
        end

        rows = scope.pluck(*selects)
        rows = rows.map { |values| aliases.zip(Array(values)).to_h }

        @dataset = rows
        @ruby_loaded_data = nil
        [rows, nil]
      end

      def build_join_hash(paths)
        result = {}
        paths.each do |path|
          next if path.empty?
          current = result
          path.each do |assoc|
            current[assoc] ||= {}
            current = current[assoc]
          end
        end
        simplify_join_hash(result)
      end

      def simplify_join_hash(hash)
        hash.map do |k, v|
          v.empty? ? k : { k => simplify_join_hash(v) }
        end
      end

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

      def initialize(dataset, ruby_loaders)
        @dataset = dataset
        @ruby_loaders = ruby_loaders
      end
    end
  end
end
