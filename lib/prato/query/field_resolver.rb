# frozen_string_literal: true

module Prato
  module Query
    # Module that handles converting user input fields into internal fields.
    module FieldResolver
      SEPARATOR = "___".freeze

      def self.join(parts)
        parts = Array(parts)
        parts.length == 1 ? parts.first.to_sym : parts.map(&:to_s).join(SEPARATOR).to_sym
      end

      def self.resolve_context(spec, config)
        ->(field) do

        end
      end
    end
  end
end