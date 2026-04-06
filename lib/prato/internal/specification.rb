# frozen_string_literal: true

module Prato
  module Internal
    class Specification
      attr_reader :columns, :visible_fields, :ruby_loaders, :field_lookup, :config

      def initialize(columns:,
                     visible_fields:,
                     filterable_fields:,
                     sortable_fields:,
                     output_paths:,
                     field_lookup:,
                     ruby_loaders:,
                     config:)
        @columns = columns
        @visible_fields = visible_fields
        @filterable_fields = filterable_fields
        @sortable_fields = sortable_fields
        @output_paths = output_paths
        @field_lookup = field_lookup
        @ruby_loaders = ruby_loaders
        @config = config
      end

      def validate_and_extract_materialization_fields(params)
        return @visible_fields if params.nil?

        fields = []

        return nil unless collect_filter_fields(params.filters, fields)
        return nil unless collect_sort_fields(params.sorts, fields)
        return nil unless collect_display_fields(params.fields, fields)

        fields.uniq
      end

      def field_mapping(field_name)
        @output_paths[field_name]
      end

      def sql_only?(display_fields)
        display_fields.none? { |f| @columns[f].is_a?(Types::RubyColumn) }
      end

      private

      def collect_filter_fields(filters, fields)
        return true if filters.nil?

        Array(filters).all? do |filter|
          case filter
          when Query::Filter
            if @filterable_fields.include?(filter.field)
              fields << filter.field
              true
            else
              false
            end
          when Query::AndFilter, Query::OrFilter
            collect_filter_fields(filter.filters, fields)
          end
        end
      end

      def collect_sort_fields(sorts, fields)
        return true if sorts.nil?

        Array(sorts).all? do |sort|
          if @sortable_fields.include?(sort.field)
            fields << sort.field
            true
          else
            false
          end
        end
      end

      def collect_display_fields(display, fields)
        if display.nil?
          fields.concat(@visible_fields)
          return true
        end

        Array(display).all? do |field|
          if @visible_fields.include?(field)
            fields << field
            true
          else
            false
          end
        end
      end
    end
  end
end
