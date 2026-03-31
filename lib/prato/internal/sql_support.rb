# frozen_string_literal: true

module Prato
  module Internal
    module SqlSupport
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

      def join_hash_for(path)
        return path.first if path.length == 1

        path.reverse.reduce { |inner, outer| { outer => inner } }
      end

      def join_hashes_for(paths)
        result = {}

        paths.each do |path|
          next if path.empty?

          current = result
          path.each do |assoc|
            current[assoc] ||= {}
            current = current[assoc]
          end
        end

        simplify_join_hash(result)
      end

      def table_for(scope, association_path)
        return scope.model.arel_table if association_path.empty?

        join_dependencies_for(scope).each do |join_dependency|
          node = find_node(join_dependency.send(:join_root), association_path)
          return node.table if node
        end

        raise ArgumentError, "Unable to resolve SQL table alias for association path #{association_path.inspect}"
      end

      private

      def join_dependencies_for(scope)
        if scope.respond_to?(:build_join_buckets, true)
          buckets, join_type = scope.send(:build_join_buckets)

          join_dependency = scope.construct_join_dependency(buckets[:named_join], join_type)
          alias_tracker = scope.alias_tracker(buckets[:leading_join] + buckets[:join_node])

          stashed_join_dependencies = buckets[:stashed_join]

          join_dependency.join_constraints(stashed_join_dependencies, alias_tracker, scope.references_values)
          [join_dependency, *stashed_join_dependencies]
        else
          alias_tracker = scope.alias_tracker
          join_dependencies = []

          joins_values = named_joins_for(scope.joins_values)
          unless joins_values.empty?
            join_dependency = ActiveRecord::Associations::JoinDependency.new(scope.model, scope.table, joins_values)
            join_dependency.join_constraints([], Arel::Nodes::InnerJoin, alias_tracker)
            join_dependencies << join_dependency
          end

          left_outer_joins_values = named_joins_for(scope.left_outer_joins_values)
          unless left_outer_joins_values.empty?
            join_dependency = ActiveRecord::Associations::JoinDependency.new(scope.model, scope.table,
                                                                             left_outer_joins_values)
            join_dependency.join_constraints([], Arel::Nodes::OuterJoin, alias_tracker)
            join_dependencies << join_dependency
          end

          join_dependencies
        end
      end

      def named_joins_for(join_values)
        Array(join_values).flat_map do |join_value|
          if join_value.is_a?(Array)
            named_joins_for(join_value)
          elsif join_value.is_a?(Hash) || join_value.is_a?(Symbol)
            [join_value]
          else
            []
          end
        end
      end

      def find_node(root, association_path)
        association_path.each do |assoc_name|
          root = root.children.find { |child| child.reflection.name == assoc_name }
          return nil unless root
        end

        root
      end

      def simplify_join_hash(hash)
        hash.map do |key, value|
          value.empty? ? key : { key => simplify_join_hash(value) }
        end
      end
    end
  end
end
