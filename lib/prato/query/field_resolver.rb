# frozen_string_literal: true

module Prato
  module Query
    # Module that handles converting user input fields into internal fields.
    module FieldResolver
      extend self

      SEPARATOR = "___".freeze

      def join(parts)
        parts = Array(parts)
        parts.length == 1 ? parts.first.to_sym : parts.map(&:to_s).join(SEPARATOR).to_sym
      end

      def resolve_context(field_lookup)
        ->(fields) do
          field_lookup[fields]
        end
      end
    end
  end
end