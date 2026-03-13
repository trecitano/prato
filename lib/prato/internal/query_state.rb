# frozen_string_literal: true

module Prato
  module Internal
    class QueryState
      attr_reader :dataset, :ruby_loaders, :applied_scopes, :required_fields

      def self.create(base_scope, required_fields)
        dataset = base_scope.dup
        ruby_loaders = {}
        applied_scopes = []

        new(dataset, ruby_loaders, applied_scopes, required_fields)
      end

      def self.build_required_columns(spec, fields:, filters:, sorts:)
        requested_fields = fields || spec.all_fields
        filter_fields = extract_filter_fields(filters)
        sort_fields = extract_sort_fields(sorts)
        normalize_field_paths(requested_fields + filter_fields + sort_fields).uniq
      end

      def with_dataset(dataset)
        self.class.new(dataset, ruby_loaders, applied_scopes, required_fields)
      end

      def unmaterialized?
        !dataset.is_a?(Array)
      end

      def materialized_dataset(spec)
        return [dataset, @ruby_loaded_data] unless unmaterialized?

        columns = spec.columns
        scope = dataset
        base_table = scope.model.arel_table

        # 1. Build selects and collect associations
        selects = Set.new
        selects << base_table[scope.model.primary_key.to_sym]

        association_paths = []

        @required_fields.each do |field|
          column = columns[field]

          case column
          when Types::AggregateColumn
            sql_alias = field.is_a?(Array) ? field.join("__") : field.to_s
            selects << column.arel_node.as(sql_alias)
          when Types::Column
            if column.association_path
              association_paths << column.association_path
              # Include foreign key so .includes() can match
              reflection = scope.model.reflect_on_association(column.association_path.first)
              selects << base_table[reflection.foreign_key.to_sym]
            else
              selects << column.arel_node
            end
          when Types::RubyColumn
            selects = Set.new([Arel.sql("#{scope.model.table_name}.*")])
            break
          end
        end

        # 2. Includes for association columns
        if association_paths.any?
          includes = build_associations(association_paths.uniq)
          scope = scope.includes(includes)
        end

        # 3. Apply column scopes
        @required_fields.each do |field|
          column = columns[field]
          next unless column.is_a?(Types::Column) && column.scope

          scope = scope.public_send(column.scope)
        end

        # 4. Select and materialize
        scope = scope.select(selects.to_a)
        records = scope.to_a

        # 5. Ruby loaders
        ruby_loaded_data = nil
        if spec.ruby_loaders&.any?
          ruby_loaded_data = LazyLoaderCache.new(records)
          spec.ruby_loaders.each { |key, block| ruby_loaded_data[key] = block }
        end

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

      def initialize(dataset, ruby_loaders, applied_scopes, required_fields)
        @dataset = dataset
        @ruby_loaders = ruby_loaders
        @applied_scopes = applied_scopes
        @required_fields = required_fields
      end
    end
  end
end
