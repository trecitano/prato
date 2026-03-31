# frozen_string_literal: true

module Prato
  module Types
    class RubyColumn
      def initialize(loader, key:)
        @loader = loader
        @key = key || :id
      end

      def extract_value(record, ruby_data)
        key_value = case @key
                    when Array
                      @key.reduce(record) { |obj, method| obj.public_send(method) }
                    when Symbol
                      record.public_send(@key)
                    else
                      @key
                    end

        ruby_data[@loader]&.[](key_value)
      end
    end
  end
end
