# frozen_string_literal: true
require "active_record/version"
module Prato
  module Internal
    module ActiveRecordVersion
      extend self

      LEGACY_CUTOFF = Gem::Version.new("5.2").freeze
      MINIMUM_AREL_DESC_VERSION = Gem::Version.new("6.0").freeze

      def version
        @version ||= Gem::Version.new(ActiveRecord::VERSION::STRING)
      end

      def legacy?
        version < LEGACY_CUTOFF
      end

      def supports_arel_desc?
        version >= MINIMUM_AREL_DESC_VERSION
      end
    end
  end
end