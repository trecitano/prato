# frozen_string_literal: true

module Prato
  class Configuration

    class << self
      def config
        @config ||= Configuration.new
      end

      def configure
        yield(config) if block_given?
        config
      end
    end

    attr_accessor :key_transformation,
                  :on_invalid_input,
                  :parameter_parser,
                  :default_page_size,
                  :maximum_page_size,
                  :default_filterable,
                  :default_sortable

    def initialize
      @key_transformation = :camelCase
      @on_invalid_input = :empty
      @parameter_parser = Prato::Query::DefaultParser.new
      @default_page_size = 20
      @maximum_page_size = 100
      @default_filterable = true
      @default_sortable = true
    end

    KEY_TRANSFORMATION_OPTIONS = [ :camelCase, :snake_case, :none].freeze
    def key_transformation=(value)
      raise ArgumentError unless KEY_TRANSFORMATION_OPTIONS.include?(value)

      @key_transformation = value
    end

    INVALID_INPUT_OPTIONS = [:empty, :raise].freeze
    def on_invalid_input=(value)
      raise ArgumentError unless INVALID_INPUT_OPTIONS.include?(value)

      @on_invalid_input = value
    end

    def parameter_parser=(parser)
      unless parser.respond_to?(:parse_parameters)
        raise ArgumentError,
              "parameter_parser must respond to .parse_parameters. Got #{parser.inspect}"
      end

      @parameter_parser = parser
    end

    def default_filterable=(value)
      raise ArgumentError, "default_filterable must be a boolean" unless value == true || value == false

      @default_filterable = value
    end

    def default_sortable=(value)
      raise ArgumentError, "default_sortable must be a boolean" unless value == true || value == false

      @default_sortable = value
    end
  end
end
