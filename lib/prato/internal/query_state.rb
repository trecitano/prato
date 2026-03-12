# frozen_string_literal: true

module Prato
  module Internal
    class QueryState
      attr_reader :dataset, :ruby_loaders, :applied_scopes, :wrapped_for_computed, :required_fields

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
        self.class.new(dataset, ruby_loaders, applied_scopes, wrapped_for_computed, @required_fields)
      end

      def unmaterialized?
        !dataset.is_a?(Array)
      end

      def materialized_dataset(spec)
        association_paths = association_paths(spec.columns, @required_fields)
        associations = build_associations(association_paths)

        scoped_query_state = apply_necessary_column_scopes(spec.columns, @required_fields)

        base_scope = scoped_query_state.dataset
        scope_with_includes = base_scope.includes(associations)

        scope_with_selected_columns = select_columns(scope_with_includes, spec.columns, @required_fields)

        records = scope_with_selected_columns.to_a

        if spec.ruby_loaders&.any?
          ruby_loaded_data = ::Prato::Internal::LazyLoaderCache.new(records)
          spec.ruby_loaders.each do |key, block|
            ruby_loaded_data[key] = block
          end
        end

        [records, ruby_loaded_data]
      end

      private

      # Given a list of fields, we obtain the corresponding column associations
      def association_paths(columns, fields)
        associations = []

        fields.each do |field|
          column = columns[field]
          next unless column.is_a?(Types::Column)

          accessor = column.accessor
          associations << accessor[0..-2] if accessor.is_a?(Array) && accessor.length > 1
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
          column = columns[field]
          if column.is_a?(Types::Column) && !column.scope.nil?
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

        required_columns.each do |field|
          column = columns[field]
          next unless column.is_a?(Types::AggregateColumn)

          columns_to_select << build_aggregate_subquery(base_model, table_name, field, column)
        end

        scope.select(columns_to_select.uniq.join(", "))
      end

      def build_aggregate_subquery(base_model, base_table_name, field, column)
        path = column.association_path
        reflections = resolve_association_path(base_model, path)

        # The deepest association is the target table for the aggregate
        target_reflection = reflections.last
        target_table = target_reflection.klass.table_name

        # Start the subquery from the target table
        subquery = target_reflection.klass.all

        # Build joins from deepest back to second association
        # (first association correlates to the base table via WHERE)
        reflections.reverse_each.each_cons(2) do |child_ref, parent_ref|
          parent_table = parent_ref.klass.table_name
          child_table = child_ref.klass.table_name

          subquery = subquery.joins(
            "INNER JOIN #{parent_table} ON #{parent_table}.#{parent_ref.klass.primary_key} = #{child_table}.#{child_ref.foreign_key}"
          )

          if child_ref.scope && child_ref.scope.arity.zero?
            subquery = subquery.merge(child_ref.klass.instance_exec(&child_ref.scope))
          end
        end

        # Correlate the first association back to the base table
        first_ref = reflections.first
        first_table = first_ref.klass.table_name
        subquery = subquery.where(
          "#{first_table}.#{first_ref.foreign_key} = #{base_table_name}.#{first_ref.active_record_primary_key}"
        )

        # Apply scope on the first association (e.g. scoped has_many)
        if first_ref.scope && first_ref.scope.arity.zero?
          subquery = subquery.merge(first_ref.klass.instance_exec(&first_ref.scope))
        end

        aggregate_expr = build_aggregate_expression(column, target_table)
        sql_alias = field.is_a?(Array) ? field.join("__") : field
        "(#{subquery.select(aggregate_expr).to_sql}) AS #{sql_alias}"
      end

      def resolve_association_path(base_model, path)
        current_model = base_model

        path.map do |assoc_name|
          reflection = current_model.reflect_on_association(assoc_name)
          raise ArgumentError, "Unknown association '#{assoc_name}' on #{current_model}" unless reflection

          if reflection.is_a?(ActiveRecord::Reflection::ThroughReflection)
            raise NotImplementedError, "Aggregate columns on :through associations are not yet supported"
          end

          current_model = reflection.klass
          reflection
        end
      end

      def build_aggregate_expression(column, table_name)
        case column.aggregate_function
        when :count
          "COUNT(*)"
        when :sum
          "COALESCE(SUM(#{table_name}.#{column.aggregate_field}), 0)"
        when :avg
          "AVG(#{table_name}.#{column.aggregate_field})"
        when :min
          "MIN(#{table_name}.#{column.aggregate_field})"
        when :max
          "MAX(#{table_name}.#{column.aggregate_field})"
        end
      end

      def initialize(dataset, ruby_loaders, applied_scopes, wrapped_for_computed, required_fields)
        @dataset = dataset
        @ruby_loaders = ruby_loaders
        @applied_scopes = applied_scopes
        @wrapped_for_computed = wrapped_for_computed
        @required_fields = required_fields
      end
    end
  end
end
