# frozen_string_literal: true

module Prato
  module Internal
    module Pipeline
      module Pagination
        extend self

        def paginate(query_state, page, per_page)
          records = query_state.records
          offset = (page - 1) * per_page

          paginated_records = if query_state.unmaterialized?
                                records.offset(offset).limit(per_page)
                              else
                                records.slice(offset, per_page) || []
                              end

          query_state.with_records(paginated_records)
        end
      end
    end
  end
end
