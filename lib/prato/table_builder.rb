# frozen_string_literal: true

module Prato
  class TableBuilder

    attr_reader :spec_builder

    def initialize
      @spec_builder = Internal::SpecificationBuilder.new
    end

    def column(*args, **kwargs)
      @spec_builder.inner_column(*args, **kwargs)
    end

    def ruby_column(*args, **kwargs, &block)
      @spec_builder.inner_ruby_column(*args, **kwargs, &block)
    end

    def query_column(*args, **kwargs)
      @spec_builder.inner_query_column(*args, **kwargs)
    end

    def section(id, &block)
      raise ArgumentError, "Section requires a block" unless block_given?
      raise ArgumentError, "Section block must not accept arguments" unless block.parameters.empty?

      @spec_builder.inner_section(id, &block)
    end

    def ruby_loader(id, &block)
      @spec_builder.inner_ruby_loader(id, &block)
    end

    def configure(config = nil, **overrides)
      resolved_config = Configuration.with_settings(config, **overrides)
      @spec_builder.inner_config(resolved_config)
    end
  end
end
