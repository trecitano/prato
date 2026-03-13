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

      def extract_value(record, ruby_data)
        key_value = record.public_send(key)

        ruby_data[loader]&.[](key_value)
      end
    end
  end
end
