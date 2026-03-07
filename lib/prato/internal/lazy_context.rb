# frozen_string_literal: true

module Prato
  module Internal
    class LazyContext < Hash
      def initialize(records)
        super(records)

        @records = records
      end

      def [](key)
        value = super

        if value.is_a?(Proc)
          result = value.call(@records, self)
          self[key] = result # memoize the result
          result
        else
          value
        end
      end
    end
  end
end
