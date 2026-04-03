# frozen_string_literal: true

module Prato
  module Internal
    module SqlSupport
      extend self

      def table_for(scope, association_path)
        return scope.model.arel_table if association_path.empty?

        expanded = expand_through_associations(scope.model, association_path)
        join_sources = scope.arel.join_sources

        table = walk_join_path(scope.model, scope.model.arel_table, expanded, join_sources)

        unless table
          raise ArgumentError,
                "Unable to resolve table alias for association path #{association_path.inspect}"
        end

        table
      end

      private

      def expand_through_associations(model, path)
        expanded = []
        current_model = model

        path.each do |assoc_name|
          reflection = current_model.reflect_on_association(assoc_name)
          raise ArgumentError, "Unknown association '#{assoc_name}' on #{current_model}" unless reflection

          expand_reflection(reflection, expanded)
          current_model = reflection.klass
        end

        expanded
      end

      def expand_reflection(reflection, result)
        if reflection.through_reflection?
          expand_reflection(reflection.through_reflection, result)
          expand_reflection(reflection.source_reflection, result)
        else
          result << reflection.name
        end
      end

      def walk_join_path(model, parent_table, path, join_sources)
        return parent_table if path.empty?

        assoc_name, *rest = path
        reflection = model.reflect_on_association(assoc_name)
        return nil unless reflection

        fk = reflection.foreign_key.to_s
        target_table_name = reflection.klass.table_name
        parent_id = table_identifier(parent_table)

        join_sources.each do |join|
          joined_table = join.left
          next unless base_table_name(joined_table) == target_table_name
          next unless on_has_fk?(join.right.expr, fk)
          next unless on_references?(join.right.expr, parent_id)

          result = walk_join_path(reflection.klass, joined_table, rest, join_sources)
          return result if result
        end

        nil
      end

      def base_table_name(table)
        case table
        when Arel::Nodes::TableAlias then table.left.name
        when Arel::Table then table.name
        end
      end

      def table_identifier(table)
        case table
        when Arel::Nodes::TableAlias then table.right.to_s
        when Arel::Table then table.name
        end
      end

      def on_has_fk?(expr, fk)
        each_equality(expr).any? do |eq|
          attr_named?(eq.left, fk) || attr_named?(eq.right, fk)
        end
      end

      def on_references?(expr, parent_id)
        each_equality(expr).any? do |eq|
          attr_from_table?(eq.left, parent_id) || attr_from_table?(eq.right, parent_id)
        end
      end

      def attr_named?(node, name)
        node.respond_to?(:name) && node.name.to_s == name
      end

      def attr_from_table?(node, table_id)
        node.respond_to?(:relation) && table_identifier(node.relation) == table_id
      end

      def each_equality(expr, &block)
        return enum_for(:each_equality, expr) unless block

        case expr
        when Arel::Nodes::Equality then yield expr
        when Arel::Nodes::And then expr.children.each { |c| each_equality(c, &block) }
        end
      end
    end
  end
end