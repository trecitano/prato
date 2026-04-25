# frozen_string_literal: true

module Prato
  class Table
    def initialize(spec)
      @spec = spec
    end

    def page(scope, params: nil)
      Internal::QueryExecutor.execute(
        scope,
        @spec,
        raw_params: params,
        paginated: true
      )
    end

    def full(scope, params: nil)
      Internal::QueryExecutor.execute(
        scope,
        @spec,
        raw_params: params,
        paginated: false
      )
    end
  end
end
