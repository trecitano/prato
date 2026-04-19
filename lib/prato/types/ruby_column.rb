# frozen_string_literal: true

module Prato
  module Types
    class RubyColumn
      attr_reader :loader, :filter, :includes

      def initialize(loader, key:, filter: nil, includes: nil)
        @loader = loader
        @key = key || :id
        @filter = filter
        @includes = includes
      end

      def extract_value(record, ruby_data)
        key_value = case @key
                    when Proc
                      @key.call(record)
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
