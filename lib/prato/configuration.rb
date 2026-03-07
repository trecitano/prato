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

    attr_accessor :key_transformation, :strict_loading_violation, :parameter_parser, :default_page_size, :maximum_page_size

    def initialize
      @key_transformation = :camelCase
      @strict_loading_violation = true
      @parameter_parser = Prato::Query::DefaultParser
      @default_page_size = 20
      @maximum_page_size = 100
    end

    KEY_TRANSFORMATION_OPTIONS = [ :camelCase, :snake_case, :none].freeze

    def key_transformation=(value)
      raise ArgumentError unless value.is_a?(Symbol)
      raise unless KEY_TRANSFORMATION_OPTIONS.include?(value)

      @key_transformation = value
    end

    def parameters_parser=(parser)
      unless parser.respond_to?(:parse_parameters)
        raise ArgumentError,
              "parameter_parser must respond to .parse_parameters. Got #{parser.inspect}"
      end

      @parameter_parser = parser
    end
  end
end
