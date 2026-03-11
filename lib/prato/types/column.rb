# frozen_string_literal: true

module Prato
  module Types
    class Column
      attr_reader :accessor

      attr_reader :display

      attr_reader :scope

      def initialize(accessor, display: nil, scope: nil)
        @accessor = accessor
        @display = display
        @scope = scope
      end
    end
  end
end
