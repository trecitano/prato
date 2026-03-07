# frozen_string_literal: true

module Prato
  module Query
    class OrFilter
      attr_reader :filters

      def initialize(filters)
        @filters = filters
      end
    end
  end
end
