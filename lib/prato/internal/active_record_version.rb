# frozen_string_literal: true
require "active_record/version"
module Prato
  module Internal
    module ActiveRecordVersion
      extend self

      LEGACY_CUTOFF = Gem::Version.new("5.2").freeze

      def version
        @version ||= Gem::Version.new(ActiveRecord::VERSION::STRING)
      end

      def legacy?
        version < LEGACY_CUTOFF
      end
    end
  end
end