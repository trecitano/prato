# frozen_string_literal: true

module Prato
  module Types
    class Column
      attr_reader :accessor, :display, :scope

      def initialize(accessor, display: nil, scope: nil)
        @accessor = accessor
        @display = display
        @scope = scope
      end
    end
  end
end
