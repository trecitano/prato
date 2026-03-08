# frozen_string_literal: true

module Prato
  module Internal
    module Pipeline
      module Pagination
        extend self

        def paginate_query(query_state, config,raw_page, raw_per_page)
          page = raw_page || 1
          per_page = raw_per_page || config.default_page_size
          if per_page > config.maximum_page_size
            per_page = config.maximum_page_size
          end

          dataset = query_state.dataset
          offset = (page - 1) * per_page

          paginated_dataset = if query_state.unmaterialized?
                                dataset.offset(offset).limit(per_page)
                              else
                                dataset.slice(offset, per_page) || []
                              end

          query_state.with_dataset(paginated_dataset)
        end
      end
    end
  end
end
