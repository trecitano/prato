# frozen_string_literal: true

module Prato
  module Internal
    module Pipeline
      module Sorting
        extend self

        def sort_query(query_state, spec, raw_sorts)
          return query_state if raw_sorts.nil?

          sorts = Array(raw_sorts)

          any_ruby = sorts.any? { |s| spec.columns[s.field].is_a?(Types::RubyColumn) }

          if any_ruby
            apply_ruby_sorts(query_state, spec, sorts)
          else
            apply_sql_sorts(query_state, spec, sorts)
          end
        end

        private

        def apply_sql_sorts(query_state, spec, sorts)
          scope = query_state.dataset

          sorts.each do |sort|
            column = spec.columns[sort.field]
            scope = Internal::JoinHelper.ensure_join(scope, column, left_outer: true)
            node = column.sql_node_for(scope)
            order = sort.order == :desc ? node.desc : node.asc
            scope = scope.order(order)
          end

          query_state.with_dataset(scope)
        end

        def apply_ruby_sorts(query_state, spec, sorts)
          materialization_fields = (spec.visible_fields + sorts.map(&:field)).uniq
          records, ruby_data = query_state.materialized_dataset(spec, materialization_fields)

          sorted = records.sort do |a, b|
            sorts.reduce(0) do |cmp, sort|
              next cmp unless cmp.zero?

              column = spec.columns[sort.field]
              val_a = column.extract_value(a, ruby_data)
              val_b = column.extract_value(b, ruby_data)

              result = safe_compare(val_a, val_b)
              sort.order == :desc ? -result : result
            end
          end

          query_state.with_dataset(sorted)
        end

        def safe_compare(a, b)
          return 0 if a.nil? && b.nil?
          return 1 if a.nil?
          return -1 if b.nil?

          a <=> b
        end
      end
    end
  end
end
