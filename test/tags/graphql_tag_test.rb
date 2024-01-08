# frozen_string_literal: true

require "test_helper"

module PlatformosCheck
  module Tags
    class GraphqlTagTest < Minitest::Test
      def test_partial_syntax_without_arguments
        offenses = analyze_platformos_app(
          "app/views/pages/index.liquid" => <<~END
            {% graphql f = 'my_graphql' %}
          END
        )

        assert_offenses("", offenses)
      end

      def test_partial_syntax_with_argument
        offenses = analyze_platformos_app(
          "app/views/pages/index.liquid" => <<~END
            {% graphql f = 'my_graphql', arg1: arg1 %}
          END
        )

        assert_offenses("", offenses)
      end

      def test_partial_syntax_with_two_arguments
        offenses = analyze_platformos_app(
          "app/views/pages/index.liquid" => <<~END
            {% graphql f = 'my_graphql', arg1: arg1, username: data.username %}
          END
        )

        assert_offenses("", offenses)
      end

      def test_inline_syntax_without_commas
        offenses = analyze_platformos_app(
          "app/views/pages/index.liquid" => <<~END
            {% graphql result arg1: arg1 arg2: "Hello" %}
              query get($arg1: ID, $arg2: String) {
                records(
                  per_page: 1
                  filter: {
                    id: { value: $arg1 }
                    table: { value: "my_table" }
                    properties: [{ name: "arg2", value: $arg2 }]
                  }
                ) {
                  results {
                    id
                  }
                }
              }
            {% endgraphql %}
          END
        )

        assert_offenses("", offenses)
      end
    end
  end
end
