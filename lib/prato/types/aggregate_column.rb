# frozen_string_literal: true

module Prato
  module Types
    class AggregateColumn
      attr_reader :aggregate_function, :accessor

      attr_reader :association_path, :aggregate_field

      def initialize(aggregate_function, accessor)
        @accessor = Array(accessor)
        @aggregate_function = aggregate_function

        @association_path = aggregate_function == :count ? @accessor : @accessor[0..-2]
        @aggregate_field = aggregate_function == :count ? nil : @accessor[-1]
      end
    end
  end
end
