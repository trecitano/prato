# frozen_string_literal: true

module Prato
  class TableBuilder

    def initialize
      @spec = Internal::Specification.new
    end

    def column(*args, **kwargs)
      @spec.inner_column(*args, **kwargs)
    end

    def ruby_column(*args, **kwargs)
      @spec.inner_ruby_column(*args, **kwargs)
    end

    def section(id, &block)
      raise ArgumentError, "Section requires a block" unless block_given?
      raise ArgumentError, "Section block must not accept arguments" unless block.parameters.empty?

      @spec.inner_section(id, &block)
    end

    def ruby_loaders(**kwargs)
      @spec.inner_ruby_loaders(kwargs)
    end

    def configure(config)
      @spec.inner_config(config)
    end

    def build()
      @spec.validate_and_update_keys!
      @spec
    end
  end
end
