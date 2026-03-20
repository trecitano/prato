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
                  :default_only

    def initialize
      @key_transformation = :camelCase
      @on_invalid_input = :empty
      @parameter_parser = Prato::Query::DefaultParser.new
      @default_page_size = 20
      @maximum_page_size = 100
      @default_only = nil
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

    VALID_DEFAULT_ONLY = [:display, :filter, :sort].freeze
    def default_only=(value)
      raise ArgumentError, "default_only must be one of #{VALID_DEFAULT_ONLY.map(&:inspect).join(", ")}" unless VALID_DEFAULT_ONLY.include?(value)

      @default_only = value
    end
  end
end
