# frozen_string_literal: true

module Prato
  module Internal
    class Specification
      attr_reader :columns, :visible_fields, :ruby_loaders, :config

      def initialize(columns:,
                     visible_fields:,
                     filterable_fields:,
                     sortable_fields:,
                     output_paths:,
                     ruby_loaders:,
                     config:)
        @columns = columns
        @visible_fields = visible_fields
        @filterable_fields = filterable_fields
        @sortable_fields = sortable_fields
        @output_paths = output_paths
        @ruby_loaders = ruby_loaders
        @config = config
      end

      def valid_parameters?(params)
        return true if params.nil?

        return false unless valid_filters?(params.filters)
        return false unless valid_sorts?(params.sorts)
        return false unless valid_fields?(params.fields)

        true
      end

      def field_mapping(field_name)
        @output_paths[field_name]
      end

      def sql_only?(display_fields)
        display_fields.none? { |f| @columns[f].is_a?(Types::RubyColumn) }
      end

      private

      def valid_filters?(filters)
        return true if filters.nil?

        Array(filters).all? { |f| valid_filter?(f) }
      end

      def valid_filter?(filter)
        case filter
        when Query::Filter
          @filterable_fields.include?(filter.field)
        when Query::AndFilter, Query::OrFilter
          filter.filters.all? { |f| valid_filter?(f) }
        end
      end

      def valid_sorts?(sorts)
        return true if sorts.nil?

        Array(sorts).all? { |sort| @sortable_fields.include?(sort.field) }
      end

      def valid_fields?(fields)
        return true if fields.nil?

        Array(fields).all? { |field| @visible_fields.include?(field) }
      end
    end
  end
end
