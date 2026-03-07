# frozen_string_literal: true

module Prato
  module Types
    class Section
      attr_reader :id, :columns

      def initialize(id, columns)
        @id = id
        @columns = columns
      end

      def [](key)
        @columns[key]
      end
    end
  end
end
