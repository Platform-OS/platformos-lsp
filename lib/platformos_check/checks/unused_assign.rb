# frozen_string_literal: true

module PlatformosCheck
  # Checks unused {% assign x = ... %}
  class UnusedAssign < LiquidCheck
    severity :suggestion
    category :liquid
    doc docs_url(__FILE__)

    TAGS_FOR_AUTO_VARIABLE_PREPEND = Set.new(%i[graphql function background]).freeze
    FILTERS_THAT_MODIFY_OBJECT = Set.new(%w[array_add add_to_array
                                            prepend_to_array array_prepend
                                            assign_to_hash_key hash_add_key add_hash_key
                                            remove_hash_key hash_delete_key delete_hash_key]).freeze
    PREPEND_CHARACTER = '_'

    class TemplateInfo < Struct.new(:used_assigns, :assign_nodes, :includes)
      def collect_used_assigns(templates, visited = Set.new)
        collected = used_assigns
        # Check recursively inside included snippets for use
        includes.each do |name|
          if templates[name] && !visited.include?(name)
            visited << name
            collected += templates[name].collect_used_assigns(templates, visited)
          end
        end
        collected
      end
    end

    def self.single_file(**_args)
      true
    end

    def initialize
      @templates = {}
    end

    def on_document(node)
      @templates[node.app_file.name] = TemplateInfo.new(Set.new, {}, Set.new)
    end

    def on_assign(node)
      return if ignore_prepended?(node)
      return if node.value.from.filters.any? { |filter_name, *_arguments| FILTERS_THAT_MODIFY_OBJECT.include?(filter_name) }

      @templates[node.app_file.name].assign_nodes[node.value.to] = node
    end

    def on_parse_json(node)
      @templates[node.app_file.name].assign_nodes[node.value.to] = node
    end

    def on_function(node)
      return if ignore_prepended?(node)

      @templates[node.app_file.name].assign_nodes[node.value.to] = node
    end

    def on_graphql(node)
      return if node.value.to.nil?
      return if ignore_prepended?(node)

      @templates[node.app_file.name].assign_nodes[node.value.to] = node
    end

    def on_background(node)
      return if node.value.to.nil?
      return if ignore_prepended?(node)

      @templates[node.app_file.name].assign_nodes[node.value.to] = node
    end

    def on_include(node)
      return unless node.value.template_name_expr.is_a?(String)

      @templates[node.app_file.name].includes << node.value.template_name_expr
    end

    def on_variable_lookup(node)
      @templates[node.app_file.name].used_assigns << case node.value.name
                                                     when Liquid::VariableLookup
                                                       node.value.name.name
                                                     else
                                                       node.value.name
                                                     end
    end

    def on_end
      @templates.each_pair do |_, info|
        used = info.collect_used_assigns(@templates)
        info.assign_nodes.each_pair do |name, node|
          next if used.include?(name)

          add_offense("`#{name}` is never used", node:) do |corrector|
            if TAGS_FOR_AUTO_VARIABLE_PREPEND.include?(node.type_name)
              prepend_variable(node, corrector)
            else
              corrector.remove(node)
            end
          end
        end
      end
    end

    private

    def ignore_prepended?(node)
      node.value.to.start_with?(PREPEND_CHARACTER)
    end

    def prepend_variable(node, corrector)
      offset = node.markup.match(/^#{node.type_name}\s+/)[0].size

      corrector.insert_before(
        node,
        PREPEND_CHARACTER,
        (node.start_index + offset)...(node.start_index + offset)
      )
    end
  end
end
