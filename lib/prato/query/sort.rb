# frozen_string_literal: true

module Prato
  module Query
    class Sort
      attr_reader :field, :order

      def initialize(field, order)
        @field = field
        @order = order
      end
    end
  end
end
