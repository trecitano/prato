# frozen_string_literal: true

module Prato
  module Internal
    class QueryState
      attr_reader :records, :ruby_calculated_data, :applied_scopes, :wrapped_for_computed, :required_columns

      def self.create(base_scope)
        records = base_scope.dup
        ruby_calculated_data = {}

        new(records, ruby_calculated_data, [], false)
      end
    end
  end
end
