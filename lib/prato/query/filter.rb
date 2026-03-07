# frozen_string_literal: true

module Prato
  module Query
    class Filter
      attr_reader :field, :operator, :value

      def initialize(field, operator, value)
        @field = field
        @operator = operator
        @value = value
      end
    end
  end
end
