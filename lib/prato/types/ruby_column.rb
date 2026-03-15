# frozen_string_literal: true

module Prato
  module Types
    class RubyColumn

      def initialize(loader, key:)
        @loader = loader
        @key = key || :id
      end

      def extract_value(record, ruby_data)
        key_value = record.public_send(@key)

        ruby_data[@loader]&.[](key_value)
      end
    end
  end
end
