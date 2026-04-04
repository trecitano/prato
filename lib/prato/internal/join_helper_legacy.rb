# frozen_string_literal: true

# Rails 5.0 and 5.1ºs joins work in a different way, so we need to handle them...manually
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

        scope = freeze_existing_joins(scope)

        association_paths.uniq.sort_by(&:length).each do |path|
          next if join_path_resolved?(scope, path)

          prefix_length = deepest_joined_prefix_length(scope, path)
          next if prefix_length == path.length

          parent_path = path[0...prefix_length]
          parent_table = parent_path.empty? ? scope.model.arel_table : SqlSupport.table_for(scope, parent_path)
          parent_model = model_for_path(scope.model, parent_path)
          suffix = path[prefix_length..-1]

          scope = append_left_join_suffix(scope, parent_table, parent_model, suffix)
        end

        scope
      end

      private

      # Freeze pre-existing association joins into concrete join nodes before
      # adding suffix joins so Rails 5 cannot rename earlier aliases.
      def freeze_existing_joins(scope)
        frozen_scope = scope.spawn
        frozen_scope.joins_values = scope.arel.join_sources.dup
        frozen_scope.left_outer_joins_values = []
        frozen_scope.bind_values = scope.arel.bind_values.dup
        frozen_scope
      end

      def append_left_join_suffix(scope, parent_table, parent_model, suffix)
        node = build_join_node(parent_model, suffix)
        alias_tracker = build_alias_tracker(scope)

        assign_tables!(node, parent_table, alias_tracker)

        collect_join_infos(node, parent_table, parent_model).each do |info|
          scope = scope.joins(*info.joins)
          scope.bind_values += info.binds
        end

        scope
      end

      def join_path_resolved?(scope, path)
        SqlSupport.table_for(scope, path)
        true
      rescue ArgumentError
        false
      end

      def deepest_joined_prefix_length(scope, path)
        path.length.downto(0).find { |length| join_path_resolved?(scope, path[0...length]) } || 0
      end

      def model_for_path(base_model, path)
        path.reduce(base_model) do |model, assoc_name|
          reflection = model.reflect_on_association(assoc_name)
          raise ArgumentError, "Unknown association '#{assoc_name}' on #{model}" unless reflection

          reflection.klass
        end
      end

      def build_join_node(model, path)
        reflection = model.reflect_on_association(path.first)
        raise ArgumentError, "Unknown association '#{path.first}' on #{model}" unless reflection

        children = path.length > 1 ? [build_join_node(reflection.klass, path[1..-1])] : []
        ActiveRecord::Associations::JoinDependency::JoinAssociation.new(reflection, children)
      end

      def assign_tables!(node, parent_table, alias_tracker)
        node.tables = node.reflection.chain.map do |reflection|
          aliased_table_for(
            alias_tracker,
            reflection,
            table_alias_name(reflection, parent_table.table_name, reflection != node.reflection)
          )
        end

        node.children.each { |child| assign_tables!(child, node.table, alias_tracker) }
      end

      def build_alias_tracker(scope)
        method = ActiveRecord::Associations::AliasTracker.method(:create_with_joins)

        if method.parameters.length == 3
          method.call(scope.model.connection, scope.model.table_name, scope.joins_values)
        else
          method.call(scope.model.connection, scope.model.table_name, scope.joins_values, scope.model.type_caster)
        end
      end

      def aliased_table_for(alias_tracker, reflection, aliased_name)
        method = alias_tracker.method(:aliased_table_for)

        if method.parameters.length == 3
          method.call(reflection.table_name, aliased_name, reflection.klass.type_caster)
        else
          method.call(reflection.table_name, aliased_name)
        end
      end

      def collect_join_infos(node, parent_table, parent_model)
        infos = [build_join_info(node, parent_table, parent_model)]

        node.children.each do |child|
          infos.concat(collect_join_infos(child, node.table, node.base_klass))
        end

        infos
      end

      def build_join_info(node, parent_table, parent_model)
        method = node.method(:join_constraints)

        if method.parameters.length == 5
          method.call(
            parent_table,
            parent_model,
            Arel::Nodes::OuterJoin,
            node.tables,
            node.reflection.chain
          )
        else
          method.call(
            parent_table,
            parent_model,
            node,
            Arel::Nodes::OuterJoin,
            node.tables,
            node.reflection.scope_chain,
            node.reflection.chain
          )
        end
      end

      def table_alias_name(reflection, parent_table_name, join)
        name = "#{reflection.plural_name}_#{parent_table_name}"
        name << "_join" if join
        name
      end

      def join_hash_for(path)
        return path.first if path.length == 1

        path.reverse.reduce { |inner, outer| { outer => inner } }
      end
    end
  end
end
