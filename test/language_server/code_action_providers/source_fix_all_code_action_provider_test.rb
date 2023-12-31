# frozen_string_literal: true

require "test_helper"

module PlatformosCheck
  module LanguageServer
    class SourceFixAllCodeActionProviderTest < Minitest::Test
      def setup
        instances = diagnose_platformos_app(
          PlatformosCheck::SpaceInsideBraces.new,
          PlatformosCheck::TemplateLength.new(max_length: 0),
          "app/views/pages/index.liquid" => <<~LIQUID,
            {{x}}
            muffin
          LIQUID
          "app/views/pages/other.liquid" => <<~LIQUID
            cookies
          LIQUID
        )
        @storage = instances[:storage]
        @diagnostics_manager = instances[:diagnostics_manager]
        @provider = SourceFixAllCodeActionProvider.new(@storage, @diagnostics_manager)
      end

      def test_returns_code_action_that_fixes_all_diagnostics_in_file
        expected_diagnostics = @diagnostics_manager
                               .diagnostics('app/views/pages/index.liquid')
                               .select { |d| d.code == "SpaceInsideBraces" }
                               .map(&:to_h)
        expected = [
          {
            title: 'Fix all PlatformOS Check auto-fixable problems',
            kind: 'source.fixAll',
            diagnostics: expected_diagnostics,
            command: {
              title: 'fixAll.file',
              command: LanguageServer::CorrectionExecuteCommandProvider.command,
              arguments: expected_diagnostics
            }
          }
        ]

        assert_equal(expected, @provider.code_actions("app/views/pages/index.liquid", nil))
      end

      def test_returns_empty_list_if_current_version_in_storage_does_not_match_diagnostic
        @storage.write("app/views/pages/index.liquid", "got ya!", 1000)

        assert_empty(@provider.code_actions("app/views/pages/index.liquid", nil))
      end

      def test_returns_empty_list_when_nothing_is_fixable_in_file
        assert_empty(@provider.code_actions("app/views/pages/other.liquid", nil))
      end

      def test_returns_empty_list_when_file_does_not_exist
        assert_empty(@provider.code_actions("app/views/pages/oops.liquid", nil))
      end
    end
  end
end
