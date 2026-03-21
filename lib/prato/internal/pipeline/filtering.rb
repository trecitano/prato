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
            apply_sql_filter(qs, spec, detailed.filter)
          end
        end

        def apply_sql_filter(query_state, spec, filter)
          case filter
          when Query::Filter
            column = spec.columns[filter.field]
            scope = ensure_joins(query_state.dataset, column)
            condition = build_operator_condition(column.arel_node, filter.operator, filter.value)
            query_state.with_dataset(scope.where(condition))
          when Query::AndFilter
            filter.filters.reduce(query_state) { |qs, child| apply_sql_filter(qs, spec, child) }
          when Query::OrFilter
            scope = ensure_joins_for_filters(query_state.dataset, spec, filter.filters)
            condition = build_sql_condition(spec, filter)
            query_state.with_dataset(scope.where(condition))
          end
        end

        def build_sql_condition(spec, filter)
          case filter
          when Query::Filter
            column = spec.columns[filter.field]
            build_operator_condition(column.arel_node, filter.operator, filter.value)
          when Query::AndFilter
            filter.filters.map { |child| build_sql_condition(spec, child) }
                  .reduce { |a, b| a.and(b) }
          when Query::OrFilter
            filter.filters.map { |child| build_sql_condition(spec, child) }
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
          end
        end

        def ensure_joins(scope, column)
          return scope unless column.is_a?(Types::Column) && column.association_path
          scope.joins(build_join_hash(column.association_path))
        end

        def ensure_joins_for_filters(scope, spec, filters)
          filters.each do |filter|
            case filter
            when Query::Filter
              column = spec.columns[filter.field]
              scope = ensure_joins(scope, column)
            when Query::AndFilter, Query::OrFilter
              scope = ensure_joins_for_filters(scope, spec, filter.filters)
            end
          end
          scope
        end

        def build_join_hash(path)
          return path.first if path.length == 1
          path.reverse.reduce { |inner, outer| { outer => inner } }
        end

        ###################################################################
        # RUBY FILTERS
        ###################################################################

        def apply_ruby_filters(query_state, spec, detailed_filters)
          return query_state if detailed_filters.empty?

          records, ruby_data = query_state.materialized_dataset(spec, spec.visible_fields)

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
            filter.filters.all? { |child| evaluate_ruby_filter(record, spec, child, ruby_data) }
          when Query::OrFilter
            filter.filters.any? { |child| evaluate_ruby_filter(record, spec, child, ruby_data) }
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
