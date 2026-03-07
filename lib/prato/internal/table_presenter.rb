# frozen_string_literal: true

module Prato
  module Internal
    module TablePresenter
      extend self

      def present_table(scope, spec, raw_params:, paginated: true)
        spec.validate!

        config = spec.config

        params = resolve_table_parameters(raw_params, config)
        visible_columns = spec.all_column_keys

        required_columns = visible_columns.merge(params.columns)

        base_query_state = Prato::Internal::QueryState.create(scope)

        filtered_query = Prato::Internal::Pipeline::Filtering.filter(base_query_state, spec, params.filters, required_columns)
        sorted_query = Prato::Internal::Pipeline::Sorting.sort(filtered_query, spec, params.sorts, required_columns)
        paginated_query = if paginated
                            Prato::Internal::Pipeline::Pagination.paginate(sorted_query, params.page, params.per_page)
                          else
                            sorted_query
                          end
        data = Prato::Internal::Pipeline::Presenting.present(paginated_query, spec, required_columns)

        {
          entries: data,
          totalCount: paginated ? total_count(sorted_query) : data.count
        }
      end

      private

      def resolve_table_parameters(input, definition)
        return input if input.is_a?(Query::Parameters)



        parser = resolve_table_parameters_parser(definition)
        unless parser.respond_to?(:coerce)
          raise ArgumentError, "Table parameters parser must respond to .coerce. Got #{parser.inspect}"
        end

        parsed = parser.coerce(input)
        Prato::Query::Contract.validate!(parsed)
      end

      def resolve_table_parameters_parser(definition)
        structure_override = structure_config_value(definition, :table_parameters_parser, default: nil)
        structure_override || Prato::Configuration.config.default_table_parameters_parser
      end

      def run_with_strict_loading(base_scope, structure)
        strict_loading_enabled = structure_config_value(
          structure,
          :strict_loading_enabled,
          default: Prato.config.strict_loading_enabled
        )
        return yield(base_scope) unless strict_loading_enabled

        strict_loading_violation = structure_config_value(
          structure,
          :strict_loading_violation,
          default: Prato.config.strict_loading_violation
        )
        strict_loading_violation = strict_loading_violation.to_sym if strict_loading_violation.respond_to?(:to_sym)

        strict_scope = base_scope.strict_loading

        case strict_loading_violation
        when :raise
          raise_on_strict_loading_notifications do
            yield(strict_scope)
          end
        when :log
          begin
            yield(strict_scope)
          rescue ActiveRecord::StrictLoadingViolationError => e
            log_strict_loading_violation(e)
            yield(base_scope)
          end
        else
          raise ArgumentError, "Unsupported strict_loading_violation mode: #{strict_loading_violation.inspect}"
        end
      end

      def structure_config_value(structure, key, default:)
        options = structure.respond_to?(:config_options) ? structure.config_options : {}
        return default unless options.is_a?(Hash)

        if options.key?(key)
          options[key]
        elsif options.key?(key.to_s)
          options[key.to_s]
        else
          default
        end
      end

      def raise_on_strict_loading_notifications(&block)
        callback = lambda do |_event, _started, _finished, _id, payload|
          owner = payload[:owner]
          reflection = payload[:reflection]
          message = reflection&.strict_loading_violation_message(owner) || "Strict loading violation detected."

          raise ActiveRecord::StrictLoadingViolationError, message
        end

        ActiveSupport::Notifications.subscribed(callback, "strict_loading_violation.active_record", &block)
      end

      def log_strict_loading_violation(error)
        message = "[Prato] Strict loading violation detected: #{error.message}. Retrying without strict loading."

        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.warn(message)
        else
          warn(message)
        end
      end

      def total_count(query_state)
        if query_state.unmaterialized?
          query_state.effective_scope.except(:select).count
        else
          query_state.records.count
        end
      end
    end
  end
end
