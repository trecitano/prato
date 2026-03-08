# frozen_string_literal: true

module Prato
  module Internal
    module Pipeline
      module Sorting
        extend self

        def sort_query(query_state, spec, sorts)
          return query_state if sorts.nil?

        end
      end
    end
  end
end
