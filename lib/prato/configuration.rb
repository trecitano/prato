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

      def with_settings(
        base = nil,
        key_transformation: nil,
        on_invalid_input: nil,
        parameter_parser: nil,
        default_page_size: nil,
        maximum_page_size: nil,
        default_queryable: nil,
        default_ruby_column_queryable: nil
      )
        copy = (base || config).dup
        copy.key_transformation = key_transformation if key_transformation
        copy.on_invalid_input = on_invalid_input if on_invalid_input
        copy.parameter_parser = parameter_parser if parameter_parser
        copy.default_page_size = default_page_size if default_page_size
        copy.maximum_page_size = maximum_page_size if maximum_page_size
        copy.default_queryable = default_queryable if default_queryable
        copy.default_ruby_column_queryable = default_ruby_column_queryable if default_ruby_column_queryable
        copy
      end
    end

    attr_accessor :default_page_size,
                  :maximum_page_size

    attr_reader :key_transformation,
                :on_invalid_input,
                :parameter_parser,
                :default_queryable,
                :default_ruby_column_queryable

    def initialize
      @key_transformation = :camelCase
      @on_invalid_input = :empty
      @parameter_parser = Prato::Query::DefaultParser.new
      @default_page_size = 20
      @maximum_page_size = 100
      @default_queryable = :all
      @default_ruby_column_queryable = :none
    end

    KEY_TRANSFORMATION_OPTIONS = [:camelCase, :snake_case, :none].freeze
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

    VALID_QUERYABLE = [:all, :none, :filter, :sort].freeze

    def default_queryable=(value)
      @default_queryable = validate_queryable!(value, option_name: "default_queryable")
    end

    def default_ruby_column_queryable=(value)
      @default_ruby_column_queryable = validate_queryable!(value, option_name: "default_ruby_column_queryable")
    end

    private

    def validate_queryable!(value, option_name: "queryable")
      unless VALID_QUERYABLE.include?(value)
        raise ArgumentError, "#{option_name} must be one of #{VALID_QUERYABLE.map(&:inspect).join(", ")}"
      end

      value
    end
  end
end
