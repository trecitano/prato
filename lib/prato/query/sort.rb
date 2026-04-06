# frozen_string_literal: true

module Prato
  module Query
    class Sort
      attr_reader :field, :is_desc

      def initialize(field, is_desc)
        @field = field
        @is_desc = is_desc
      end
    end
  end
end
