# frozen_string_literal: true

module Prato
  class Table
    def initialize(spec)
      @spec = spec
    end

    def page(scope, params = nil)
      Internal::QueryExecutor.execute(
        scope,
        @spec,
        raw_params: params,
        paginated: true
      )
    end

    def full(scope, params = nil)
      Internal::QueryExecutor.execute(
        scope,
        @spec,
        raw_params: params,
        paginated: false
      )
    end

    def batches(scope, params = nil, batch_size: 1000, &block)
      return enum_for(:batches, scope, params, batch_size: batch_size) unless block

      Internal::QueryExecutor.execute_in_batches(
        scope,
        @spec,
        raw_params: params,
        batch_size: batch_size,
        &block
      )
    end
  end
end
