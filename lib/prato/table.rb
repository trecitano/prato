# frozen_string_literal: true

module Prato
  class Table
    def initialize(spec)
      spec.validate_and_update_keys!

      @spec = spec
    end

    def to_page(scope, params: nil)
      Internal::TablePresenter.present_table(
        scope,
        @spec,
        raw_params: params,
        paginated: true
      )
    end

    def to_table(scope, params: nil)
      Internal::TablePresenter.present_table(
        scope,
        @spec,
        raw_params: params,
        paginated: false
      )
    end
  end
end
