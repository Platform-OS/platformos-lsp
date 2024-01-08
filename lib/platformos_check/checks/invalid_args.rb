# frozen_string_literal: true

module PlatformosCheck
  class InvalidArgs < LiquidCheck
    severity :error
    category :liquid, :graphql
    doc docs_url(__FILE__)

    def on_render(node)
      add_duplicated_key_offense(node)
    end

    def on_function(node)
      add_duplicated_key_offense(node)
    end

    def on_graphql(node)
      add_duplicated_key_offense(node)

      return if node.value.inline_query

      graphql_partial = node.value.partial_name
      return unless graphql_partial.is_a?(String)

      graphql_file = platformos_app.grouped_files[GraphqlFile][graphql_partial]
      return unless graphql_file

      provided_arguments = node.value.attributes

      return if provided_arguments.include?('args')

      (provided_arguments - graphql_file.defined_arguments).each do |name|
        add_offense("Undefined argument `#{name}` provided to `#{graphql_file.relative_path}`", node:)
      end

      (graphql_file.required_arguments - provided_arguments).each do |name|
        add_offense("Required argument `#{name}` not provided to `#{graphql_file.relative_path}`", node:)
      end
    rescue GraphQL::ParseError => e
      add_offense("GraphQL Parse error triggered by `#{graphql_file.relative_path}`: #{e.message}", node:)
    end

    def add_duplicated_key_offense(node)
      node.value.duplicated_attrs.each do |duplicated_arg|
        add_offense("Duplicated argument `#{duplicated_arg}`", node:) do |corrector|
          match = node.markup.match(/(?<attribute>,?\s*#{duplicated_arg}\s*:\s*#{Liquid::QuotedFragment})\s*/)
          corrector.replace(node, node.markup.sub(match[:attribute], ''), node.start_index...node.end_index)
        end
      end
    end
  end
end
