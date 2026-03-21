# frozen_string_literal: true

require_relative "prato/version"

require_relative "prato/query/filter"
require_relative "prato/query/sort"
require_relative "prato/query/and_filter"
require_relative "prato/query/or_filter"
require_relative "prato/query/parameters"
require_relative "prato/query/field_path"
require_relative "prato/query/default_parser"

require_relative "prato/configuration"

require_relative "prato/types/column"
require_relative "prato/types/expression_column"
require_relative "prato/types/aggregate_column"
require_relative "prato/types/ruby_column"

require_relative "prato/internal/lazy_loader_cache"
require_relative "prato/internal/query_state"
require_relative "prato/internal/specification"
require_relative "prato/internal/specification_builder"

require_relative "prato/internal/pipeline/filtering"
require_relative "prato/internal/pipeline/pagination"
require_relative "prato/internal/pipeline/serializer"
require_relative "prato/internal/pipeline/sorting"

require_relative "prato/table"
require_relative "prato/table_builder"
require_relative "prato/internal/table_presenter"

module Prato
  extend self

  def table(base_model, &block)
    raise ArgumentError, "Prato.table requires a block" unless block_given?
    raise ArgumentError, "Prato.table block must not accept arguments" unless block.parameters.empty?

    builder = TableBuilder.new
    builder.instance_exec(&block)

    spec = builder.spec_builder.build(base_model)

    Table.new(spec)
  end

  def setup
    Configuration.new
  end
end
