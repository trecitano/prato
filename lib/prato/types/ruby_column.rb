# frozen_string_literal: true

module Prato
  module Types
    class RubyColumn
      attr_reader :id

      attr_reader :loader

      attr_reader :key

      def initialize(id, source:, key:)
        @id = id
        @source = source
        @key = key
      end
    end
  end
end
