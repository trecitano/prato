# frozen_string_literal: true

module Prato
  module Internal
    module QueryExecutor
      extend self

      def execute(scope, spec, raw_params:, paginated: true)
        config = spec.config
        params = resolve_parameters(raw_params, config, spec)

        materialization_fields = spec.validate_and_extract_materialization_fields(params)
        return invalid_input_result(config) if materialization_fields.nil?

        base_query_state = QueryState.create(scope, materialization_fields)

        filtered_query = Pipeline::Filtering.filter_query(base_query_state, spec, params&.filters)
        sorted_query = Pipeline::Sorting.sort_query(filtered_query, spec, params&.sorts)
        paginated_query = paginated ? Pipeline::Pagination.paginate_query(sorted_query, config, params&.page, params&.per_page) : sorted_query
        data = Pipeline::Serializer.serialize_query(paginated_query, spec, params&.fields)

        {
          entries: data,
          totalCount: paginated ? total_count(sorted_query) : data.count
        }
      end

      def execute_in_batches(scope, spec, raw_params:, batch_size:)
        config = spec.config
        params = resolve_parameters(raw_params, config, spec)

        materialization_fields = spec.validate_and_extract_materialization_fields(params)
        if materialization_fields.nil?
          raise ArgumentError if config.on_invalid_input == :raise

          return
        end

        base_query_state = QueryState.create(scope, materialization_fields)
        filtered_query = Pipeline::Filtering.filter_query(base_query_state, spec, params&.filters)

        if filtered_query.unmaterialized?
          filtered_query.dataset.in_batches(of: batch_size) do |relation|
            batch_state = filtered_query.with_dataset(relation)
            yield Pipeline::Serializer.serialize_query(batch_state, spec, params&.fields)
          end
        else
          filtered_query.dataset.each_slice(batch_size) do |slice|
            batch_state = filtered_query.with_dataset(slice)
            yield Pipeline::Serializer.serialize_query(batch_state, spec, params&.fields)
          end
        end
      end

      private

      def resolve_parameters(input, config, spec)
        return nil if input.nil?
        return input if input.is_a?(Query::Parameters)

        config.parameter_parser.parse_parameters(input, Prato::Query::FieldResolver.resolve_context(spec.field_lookup))
      end

      def invalid_input_result(configuration)
        raise ArgumentError if configuration.on_invalid_input == :raise

        {
          entries: [],
          totalCount: 0
        }
      end

      def total_count(query_state)
        if query_state.unmaterialized?
          query_state.dataset.except(:select).count
        else
          query_state.dataset.count
        end
      end
    end
  end
end
