# frozen_string_literal: true

module Prato
  module Internal
    module Pipeline
      module Filtering
        extend self

        def filter_query(query_state, spec, raw_filters)
          return query_state if raw_filters.nil?

          filters = Array(raw_filters)
          detailed = filters.map { |f| resolve_filter_type(spec, f) }
          sql_filters, ruby_filters = detailed.partition { |df| df.type == :sql }

          filtered_query_1 = apply_sql_filters(query_state, spec, sql_filters)
          filtered_query_2 = apply_ruby_filters(filtered_query_1, spec, ruby_filters)

          filtered_query_2
        end

        private

        def resolve_filter_type(spec, filter)
          case filter
          when Query::Filter
            column = spec.columns[filter.field]
            type = column.is_a?(Types::RubyColumn) ? :ruby : :sql
            DetailedFilter.new(type, filter)
          when Query::AndFilter, Query::OrFilter
            all_sql = filter.filters.all? { |f| resolve_filter_type(spec, f).type == :sql }
            DetailedFilter.new(all_sql ? :sql : :ruby, filter)
          end
        end

        def apply_sql_filters(query_state, spec, detailed_filters)
          detailed_filters.reduce(query_state) do |qs, detailed|
            normalized = normalize_sql_filter_tree(spec, detailed.filter)
            apply_sql_filter(qs, spec, normalized)
          end
        end

        def normalize_sql_filter_tree(spec, filter)
          case filter
          when Query::Filter
            normalize_sql_leaf_filter(spec, filter)
          when Query::AndFilter
            Query::AndFilter.new(filter.filters.map { |f| normalize_sql_filter_tree(spec, f) })
          when Query::OrFilter
            Query::OrFilter.new(filter.filters.map { |f| normalize_sql_filter_tree(spec, f) })
          end
        end

        NIL_ARRAY = [nil].freeze
        NEGATIVE_ASSC_OPS = %i[not_eq not_in not_contains].freeze
        def normalize_sql_leaf_filter(spec, filter)
          operator = filter.operator
          value = filter.value

          # Rule 1: nil values → presence operators
          if operator == :eq && value.nil?
            return Query::Filter.new(filter.field, :not_present, nil)
          end
          if operator == :not_eq && value.nil?
            return Query::Filter.new(filter.field, :present, nil)
          end

          if operator == :in && value == [nil]
            return Query::Filter.new(filter.field, :not_present, nil)
          end

          if operator == :not_in && value == [nil]
            return Query::Filter.new(filter.field, :present, nil)
          end

          # Rule 2: negative operators on association columns (non-nil values) → OrFilter with not_present
          if NEGATIVE_ASSC_OPS.include?(operator) && !value.nil? && spec.columns[filter.field].is_a?(Types::AssociationColumn)
            return Query::OrFilter.new([
              filter,
              Query::Filter.new(filter.field, :not_present, nil)
            ])
          end

          filter
        end

        def apply_sql_filter(query_state, spec, filter)
          case filter
          when Query::Filter
            column = spec.columns[filter.field]
            scope = ensure_joins(query_state.dataset, column, filter.operator)
            condition = build_operator_condition(column.sql_node_for(scope), filter.operator, filter.value)
            query_state.with_dataset(scope.where(condition))
          when Query::AndFilter
            filter.filters.reduce(query_state) { |qs, child| apply_sql_filter(qs, spec, child) }
          when Query::OrFilter
            scope = ensure_left_joins_for_filters(query_state.dataset, spec, filter.filters)
            condition = build_sql_condition(scope, spec, filter)
            query_state.with_dataset(scope.where(condition))
          end
        end

        def build_sql_condition(scope, spec, filter)
          case filter
          when Query::Filter
            column = spec.columns[filter.field]
            build_operator_condition(column.sql_node_for(scope), filter.operator, filter.value)
          when Query::AndFilter
            filter.filters.map { |child| build_sql_condition(scope, spec, child) }
                          .reduce { |a, b| a.and(b) }
          when Query::OrFilter
            filter.filters.map { |child| build_sql_condition(scope, spec, child) }
                          .reduce { |a, b| a.or(b) }
          end
        end

        def build_operator_condition(arel_node, operator, value)
          case operator
          when :eq          then arel_node.eq(value)
          when :not_eq      then arel_node.not_eq(value)
          when :lt          then arel_node.lt(value)
          when :lte         then arel_node.lteq(value)
          when :gt          then arel_node.gt(value)
          when :gte         then arel_node.gteq(value)
          when :present     then arel_node.not_eq(nil)
          when :not_present then arel_node.eq(nil)
          when :in          then arel_node.in(Array(value))
          when :not_in      then arel_node.not_in(Array(value))
          when :contains
            sanitized = ActiveRecord::Base.sanitize_sql_like(value.to_s)
            arel_node.matches("%#{sanitized}%")
          when :not_contains
            sanitized = ActiveRecord::Base.sanitize_sql_like(value.to_s)
            arel_node.does_not_match("%#{sanitized}%")
          when :between                 then arel_node.gteq(value[0]).and(arel_node.lteq(value[1]))
          when :not_between             then arel_node.lt(value[0]).or(arel_node.gt(value[1]))
          when :between_exclusive       then arel_node.gt(value[0]).and(arel_node.lt(value[1]))
          when :not_between_exclusive   then arel_node.lteq(value[0]).or(arel_node.gteq(value[1]))
          else
            raise ArgumentError, "Unknown filter operator: #{operator.inspect}"
          end
        end

        def ensure_joins(scope, column, operator)
          Internal::SqlSupport.ensure_join(scope, column, left_outer: operator == :not_present)
        end

        def ensure_left_joins_for_filters(scope, spec, filters)
          filters.each do |filter|
            case filter
            when Query::Filter
              column = spec.columns[filter.field]
              scope = Internal::SqlSupport.ensure_join(scope, column, left_outer: true)
            when Query::AndFilter, Query::OrFilter
              scope = ensure_left_joins_for_filters(scope, spec, filter.filters)
            end
          end
          scope
        end

        ###################################################################
        # RUBY FILTERS
        ###################################################################

        def apply_ruby_filters(query_state, spec, detailed_filters)
          return query_state if detailed_filters.empty?

          materialization_fields = (spec.visible_fields + filter_fields(detailed_filters.map(&:filter))).uniq
          records, ruby_data = query_state.materialized_dataset(spec, materialization_fields)

          filtered = records.select do |record|
            detailed_filters.all? { |df| evaluate_ruby_filter(record, ruby_data, spec, df.filter) }
          end

          query_state.with_dataset(filtered)
        end

        def evaluate_ruby_filter(record, ruby_data, spec, filter)
          case filter
          when Query::Filter
            column = spec.columns[filter.field]
            actual = column.extract_value(record, ruby_data)
            compare_value(actual, filter.operator, filter.value)
          when Query::AndFilter
            filter.filters.all? { |child| evaluate_ruby_filter(record, ruby_data, spec, child) }
          when Query::OrFilter
            filter.filters.any? { |child| evaluate_ruby_filter(record, ruby_data, spec, child) }
          end
        end

        def compare_value(actual, operator, expected)
          case operator
          when :eq            then actual == expected
          when :not_eq        then actual != expected
          when :lt            then !actual.nil? && actual < expected
          when :lte           then !actual.nil? && actual <= expected
          when :gt            then !actual.nil? && actual > expected
          when :gte           then !actual.nil? && actual >= expected
          when :present       then !actual.nil?
          when :not_present   then actual.nil?
          when :in            then Array(expected).include?(actual)
          when :not_in        then !Array(expected).include?(actual)
          when :contains      then actual.to_s.include?(expected.to_s)
          when :not_contains  then !actual.to_s.include?(expected.to_s)
          when :between       then !actual.nil? && actual >= expected[0] && actual <= expected[1]
          when :not_between   then !actual.nil? && (actual < expected[0] || actual > expected[1])
          when :between_exclusive     then !actual.nil? && actual > expected[0] && actual < expected[1]
          when :not_between_exclusive then !actual.nil? && (actual <= expected[0] || actual >= expected[1])
          else
            raise ArgumentError, "Unknown filter operator: #{operator.inspect}"
          end
        end

        def filter_fields(filters)
          filters.flat_map do |filter|
            case filter
            when Query::Filter
              [filter.field]
            when Query::AndFilter, Query::OrFilter
              filter_fields(filter.filters)
            else
              []
            end
          end
        end

      end

      class DetailedFilter
        attr_reader :type, :filter

        def initialize(type, filter)
          @type = type
          @filter = filter
        end
      end
    end
  end
end
