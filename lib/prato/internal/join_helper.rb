# frozen_string_literal: true

module Prato
  module Internal
    module JoinHelper
      extend self

      def ensure_join(scope, column, left_outer: false)
        return scope unless column.is_a?(Types::AssociationColumn)

        join_hash = join_hash_for(column.association_path)
        left_outer ? scope.left_joins(join_hash) : scope.joins(join_hash)
      end

      def ensure_left_joins(scope, association_paths)
        return scope if association_paths.empty?

        scope.left_joins(*join_hashes_for(association_paths))
      end

      private

      def join_hash_for(path)
        return path.first if path.length == 1

        path.reverse.reduce { |inner, outer| { outer => inner } }
      end

      def join_hashes_for(paths)
        result = {}

        paths.each do |path|
          current = result
          path.each do |assoc|
            current[assoc] ||= {}
            current = current[assoc]
          end
        end

        simplify_join_hash(result)
      end

      def simplify_join_hash(hash)
        hash.map { |key, value| value.empty? ? key : { key => simplify_join_hash(value) } }
      end
    end
  end
end