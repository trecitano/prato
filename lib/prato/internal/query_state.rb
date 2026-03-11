# frozen_string_literal: true

module Prato
  module Internal
    class QueryState
      attr_reader :dataset, :ruby_loaders, :applied_scopes, :wrapped_for_computed, :required_columns

      def self.create(base_scope, required_fields)
        dataset = base_scope.dup
        ruby_loaders = {}
        applied_scopes = []
        wrapped_for_computed = []

        new(dataset, ruby_loaders, applied_scopes, wrapped_for_computed, required_fields)
      end

      def self.build_required_columns(spec, fields:, filters:, sorts:)
        requested_fields = fields || spec.all_fields
        filter_fields = extract_filter_fields(filters)
        sort_fields = extract_sort_fields(sorts)
        normalize_field_paths(requested_fields + filter_fields + sort_fields).uniq
      end

      def with_dataset(dataset)
        self.class.new(dataset, ruby_loaders, applied_scopes, wrapped_for_computed, required_columns)
      end

      def unmaterialized?
        !dataset.is_a?(Array)
      end

      def materialized_dataset(spec)
        association_paths = association_paths(spec.columns, @required_fields)
        associations = build_associations(association_paths)

        scoped_query_state = apply_necessary_column_scopes(spec.columns, @required_columns)

        base_scope = scoped_query_state.dataset
        scope_with_includes = base_scope.includes(associations)

        scope_with_selected_columns = select_columns(scope_with_includes, spec.columns, @required_columns)

        records = scope_with_selected_columns.to_a

        if structure.has_context?
          calculated_data = ::Prato::Internal::LazyContext.new(records)
          structure.context_mappings.each do |key, computation|
            calculated_data[key] = computation
          end
        end
      end

      private

      # Given a list of fields, we obtain the corresponding column associations
      def association_paths(columns, fields)
        associations = []

        fields.each do |field|
          key, *rest = field
          column = columns[key]

          if column.is_a?(Type::Section)
            associations.concat(infer_associations(column.columns, rest))
          else
            accessor = column.accessor

            associations << accessor[0..-2] if accessor.is_a?(Array) && accessor.length > 1
          end
        end

        associations.uniq
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

      def apply_necessary_column_scopes(columns, fields)
        scopes_to_apply = collect_scopes_recursively(columns, fields)

        scopes_to_apply.reduce(self) do |query_state, scope_name|
          query_state.apply_scope(scope_name)
        end
      end

      def collect_scopes_recursively(columns, fields)
        scopes = []

        fields.each do |field|
          key, *rest = field
          column = columns[key]

          if column.is_a?(Types::Section)
            scopes.concat(collect_scopes_recursively(column.columns, rest))
          elsif column.is_a?(Types::Column) && !column.scope.nil?
            scopes << column.scope
          end
        end

        scopes.compact.uniq
      end

      def select_columns(scope, columns, required_columns)
        base_model = scope.model
        table_name = base_model.table_name

        # TODO: This needs to be improved
        columns_to_select = ["#{table_name}.*"]

        scope.select(columns_to_select.uniq.join(', '))
      end

      def initialize(dataset, ruby_loaders, applied_scopes, wrapped_for_computed, required_columns)
        @dataset = dataset
        @ruby_loaders = ruby_loaders
        @applied_scopes = applied_scopes
        @wrapped_for_computed = wrapped_for_computed
        @required_columns = required_columns
      end
    end
  end
end
