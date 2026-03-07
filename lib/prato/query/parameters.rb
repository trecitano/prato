# frozen_string_literal: true

module Prato
  module Query
    class Parameters
      attr_reader :page, :per_page, :filters, :sorts, :fields

      def initialize(page: nil, per_page: nil, filters: nil, sorts: nil, fields: nil)
        @page = page
        @per_page = per_page
        @filters = filters
        @sorts = sorts
        @fields = fields
      end
    end
  end
end
