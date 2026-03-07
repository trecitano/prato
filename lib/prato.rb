# frozen_string_literal: true

require_relative "prato/version"

require_relative "prato/query/filter"
require_relative "prato/query/sort"
require_relative "prato/query/and_filter"
require_relative "prato/query/or_filter"
require_relative "prato/query/parameters"
require_relative "prato/query/default_parser"

require_relative "prato/configuration"

require_relative "prato/types/column"
require_relative "prato/types/ruby_column"
require_relative "prato/types/section"

require_relative "prato/internal/lazy_context"
require_relative "prato/internal/query_state"
require_relative "prato/internal/specification"

require_relative "prato/internal/pipeline/common"
require_relative "prato/internal/pipeline/filtering"
require_relative "prato/internal/pipeline/pagination"
require_relative "prato/internal/pipeline/presenting"
require_relative "prato/internal/pipeline/sorting"

require_relative "prato/table"
require_relative "prato/internal/table_presenter"

module Prato
  extend self

  def table
    Prato::Table.new
  end

  def configure
    Configuration.new
  end
end
