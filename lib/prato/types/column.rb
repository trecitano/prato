# frozen_string_literal: true

module Prato
  module Types
    class Column
      attr_reader :id

      attr_reader :accessor

      attr_reader :display

      attr_reader :scope

      def initialize(id, accessor, display: nil, scope: nil)
        @id = id
        @accessor = accessor
        @display = display
        @scope = scope
      end
    end
  end
end
