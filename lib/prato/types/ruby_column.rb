# frozen_string_literal: true

module Prato
  module Types
    class RubyColumn
      attr_reader :loader

      attr_reader :key

      def initialize(loader, key:)
        @loader = loader
        @key = key
      end
    end
  end
end
