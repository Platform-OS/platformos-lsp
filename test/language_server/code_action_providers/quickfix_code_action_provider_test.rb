# frozen_string_literal: true

require "test_helper"

module PlatformosCheck
  module LanguageServer
    class QuickfixCodeActionProviderTest < Minitest::Test
      def setup
        skip "To be analyzed"
        @index = <<~LIQUID
          {{xx}}
          muffin
          {% parse_json var %}
            {
              "locales": {
                "en": { "title": "Welcome" },
                "fr": {}
              }
            }
          {% endschema %}
        LIQUID
        instances = diagnose_platformos_app(
          PlatformosCheck::SpaceInsideBraces.new,
          PlatformosCheck::TemplateLength.new(max_length: 0),
          "app/views/pages/index.liquid" => @index,
          "app/views/pages/other.liquid" => <<~LIQUID,
            cookies
          LIQUID
          "app/views/partials/only-one.liquid" => "{{x }}"
        )
        @storage = instances[:storage]
        @diagnostics_manager = instances[:diagnostics_manager]
        @provider = QuickfixCodeActionProvider.new(@storage, @diagnostics_manager)
      end

      def test_returns_relevant_code_actions_if_cursor_covers_diagnostic
        expected_diagnostic = @diagnostics_manager
                              .diagnostics("app/views/pages/index.liquid")
                              .find { |d| d.code == "SpaceInsideBraces" && d.start_index == 2 }
        code_actions = @provider.code_actions("app/views/pages/index.liquid", (0..2))
        code_action = code_actions[0]

        assert_equal(3, code_actions.size)
        assert_equal('quickfix', code_action.dig(:kind))
        assert_equal([expected_diagnostic.to_h], code_action.dig(:diagnostics))
        assert_equal('quickfix', code_action.dig(:command, :title))
        assert_equal(CorrectionExecuteCommandProvider.command, code_action.dig(:command, :command))
        assert_equal([expected_diagnostic.to_h], code_action.dig(:command, :arguments))
      end

      def test_returns_quickfix_all_actions_of_type_if_cursor_covers_a_diagnostic_and_there_are_more_than_one
        code_actions = @provider.code_actions("app/views/pages/index.liquid", (0..2))
        code_action = code_actions.find { |c| c.dig(:title) == "Fix all SpaceInsideBraces problems" }

        refute_nil(code_action, "Should find a quickfix all of type code_action")
        refute_empty(code_action.dig(:diagnostics))
        assert(code_action.dig(:diagnostics).all? { |d| d.dig(:code) == "SpaceInsideBraces" })
      end

      def test_returns_quickfix_all_actions_if_cursor_covers_a_diagnostic_and_there_are_more_than_one_diagnostic_in_the_file
        code_actions = @provider.code_actions("index.liquid", (0..2))

        refute_nil(code_actions.find { |code_action| code_action.dig(:title) == "Fix all auto-fixable problems" })
        code_actions = @provider.code_actions("only-one.liquid", (0..2))

        assert_nil(code_actions.find { |code_action| code_action.dig(:title) == "Fix all auto-fixable problems" })
      end

      def test_returns_empty_array_if_versions_dont_match
        @storage.write('app/views/pages/index.liquid', '{{ look ma I fixed it }}', 1000)

        assert_empty(@provider.code_actions("app/views/pages/index.liquid", (0..2)))
      end

      def test_returns_empty_array_if_range_does_not_cover_a_correctable_diagnostic
        assert_empty(@provider.code_actions("app/views/pages/index.liquid", (0..0)))
      end
    end
  end
end
