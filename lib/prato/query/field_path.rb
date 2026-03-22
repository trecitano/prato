# frozen_string_literal: true

module Prato
  module Query
    # Module that handles converting user input fields into internal fields.
    module FieldPath
      SEPARATOR = "___".freeze

      def self.join(parts)
        parts = Array(parts)
        parts.length == 1 ? parts.first.to_sym : parts.map(&:to_s).join(SEPARATOR).to_sym
      end
    end
  end
end