# frozen_string_literal: true

module Prato
  module Query
    class AndFilter
      attr_reader :filters

      def initialize(filters)
        @filters = filters
      end
    end
  end
end
