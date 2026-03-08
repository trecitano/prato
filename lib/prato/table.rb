# frozen_string_literal: true

module Prato
  class Table

    attr_reader :spec

    def initialize
      @spec = Internal::Specification.new
    end

    def column(*args, **kwargs)
      @spec.inner_column(*args, **kwargs)
      self
    end

    def ruby_column(*args, **kwargs)
      @spec.inner_ruby_column(*args, **kwargs)
      self
    end

    def section(id, &block)
      @spec.inner_section(id, &block)
      self
    end

    def ruby_loaders(**kwargs)
      @spec.inner_context(kwargs)
      self
    end

    def configure(config)
      @spec.inner_config(config)
      self
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
