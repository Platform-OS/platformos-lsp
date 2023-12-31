# frozen_string_literal: true

require "test_helper"

module PlatformosCheck
  module LanguageServer
    class DiagnosticsManagerTest < Minitest::Test
      Offense = Struct.new(
        :code_name,
        :app_file,
        :whole_platformos_app?
      ) do
        def single_file?
          !whole_platformos_app?
        end

        def inspect
          "#<#{code_name} app_file=\"#{app_file.path}\" #{whole_platformos_app? ? 'whole_platformos_app' : 'single_file'}>"
        end
      end
      LiquidFile = Struct.new(:relative_path, :absolute_path)

      class WholeAppOffense < Offense
        def initialize(code_name, path)
          super(code_name, LiquidFile.new(Pathname.new(path), Pathname.new(path)), true)
        end
      end

      class SingleFileOffense < Offense
        def initialize(code_name, path)
          super(code_name, LiquidFile.new(Pathname.new(path), Pathname.new(path)), false)
        end
      end

      def setup
        @diagnostics_manager = DiagnosticsManager.new
      end

      def test_reports_all_on_first_run
        assert_diagnostics(
          offenses: [
            WholeAppOffense.new("MissingTemplate", "app/views/pages/index.liquid"),
            SingleFileOffense.new("UnusedAssign", "app/views/pages/index.liquid"),
            SingleFileOffense.new("UnusedAssign", "app/views/pages/collection.liquid")
          ],
          analyzed_files: [
            "app/views/pages/index.liquid",
            "app/views/pages/collection.liquid"
          ],
          diagnostics: {
            "app/views/pages/index.liquid" => [
              WholeAppOffense.new("MissingTemplate", "app/views/pages/index.liquid"),
              SingleFileOffense.new("UnusedAssign", "app/views/pages/index.liquid")
            ],
            "app/views/pages/collection.liquid" => [
              SingleFileOffense.new("UnusedAssign", "app/views/pages/collection.liquid")
            ]
          }
        )
      end

      def test_reports_empty_when_offenses_are_fixed_in_subsequent_calls
        build_diagnostics(
          offenses: [
            SingleFileOffense.new("UnusedAssign", "app/views/pages/index.liquid"),
            SingleFileOffense.new("UnknownFilter", "app/views/pages/index.liquid"),
            SingleFileOffense.new("UnusedAssign", "app/views/pages/collection.liquid")
          ]
        )

        assert_diagnostics(
          offenses: [
            SingleFileOffense.new("UnusedAssign", "app/views/pages/collection.liquid")
          ],
          analyzed_files: [
            "app/views/pages/index.liquid",
            "app/views/pages/collection.liquid"
          ],
          diagnostics: {
            "app/views/pages/index.liquid" => [],
            "app/views/pages/collection.liquid" => [
              SingleFileOffense.new("UnusedAssign", "app/views/pages/collection.liquid")
            ]
          }
        )
        assert_diagnostics(
          offenses: [],
          analyzed_files: [
            "app/views/pages/collection.liquid"
          ],
          diagnostics: {
            "app/views/pages/collection.liquid" => []
          }
        )
      end

      def test_include_single_file_offenses_of_previous_runs
        build_diagnostics(
          offenses: [
            WholeAppOffense.new("MissingTemplate", "app/views/pages/index.liquid"),
            SingleFileOffense.new("UnusedAssign", "app/views/pages/index.liquid")
          ]
        )

        assert_diagnostics(
          offenses: [
            WholeAppOffense.new("MissingTemplate", "app/views/pages/index.liquid"),
            SingleFileOffense.new("UnusedAssign", "app/views/pages/collection.liquid")
          ],
          analyzed_files: [
            "app/views/pages/collection.liquid"
          ],
          diagnostics: {
            "app/views/pages/index.liquid" => [
              WholeAppOffense.new("MissingTemplate", "app/views/pages/index.liquid"),
              SingleFileOffense.new("UnusedAssign", "app/views/pages/index.liquid")
            ],
            "app/views/pages/collection.liquid" => [
              SingleFileOffense.new("UnusedAssign", "app/views/pages/collection.liquid")
            ]
          }
        )
      end

      def test_clears_whole_platformos_app_offenses_from_previous_runs
        build_diagnostics(
          offenses: [
            WholeAppOffense.new("MissingTemplate", "app/views/pages/index.liquid")
          ]
        )

        assert_diagnostics(
          offenses: [
            SingleFileOffense.new("UnusedAssign", "app/views/pages/collection.liquid")
          ],
          analyzed_files: [
            "app/views/pages/collection.liquid"
          ],
          diagnostics: {
            "app/views/pages/index.liquid" => [],
            "app/views/pages/collection.liquid" => [
              SingleFileOffense.new("UnusedAssign", "app/views/pages/collection.liquid")
            ]
          }
        )
      end

      def test_clears_single_platformos_app_offenses_when_missing
        build_diagnostics(
          offenses: [
            WholeAppOffense.new("MissingTemplate", "app/views/pages/index.liquid"),
            SingleFileOffense.new("UnusedAssign", "app/views/pages/index.liquid")
          ]
        )

        assert_diagnostics(
          offenses: [
            WholeAppOffense.new("MissingTemplate", "app/views/pages/index.liquid")
          ],
          analyzed_files: [
            "app/views/pages/index.liquid"
          ],
          diagnostics: {
            "app/views/pages/index.liquid" => [
              WholeAppOffense.new("MissingTemplate", "app/views/pages/index.liquid")
            ]
          }
        )
      end

      def test_diagnostics_returns_offenses_for_an_absolute_path
        build_diagnostics(
          offenses: [
            WholeAppOffense.new("MissingTemplate", "app/views/pages/index.liquid"),
            SingleFileOffense.new("UnusedAssign", "app/views/pages/index.liquid"),
            SingleFileOffense.new("SyntaxError", "app/views/pages/index.liquid"),
            SingleFileOffense.new("SyntaxError", "app/views/pages/collection.liquid")
          ]
        )
        expected = [
          WholeAppOffense.new("MissingTemplate", "app/views/pages/index.liquid"),
          SingleFileOffense.new("UnusedAssign", "app/views/pages/index.liquid"),
          SingleFileOffense.new("SyntaxError", "app/views/pages/index.liquid")
        ]

        assert_equal(expected, @diagnostics_manager.diagnostics(Pathname.new("app/views/pages/index.liquid")).map(&:offense))
        assert_equal(expected, @diagnostics_manager.diagnostics("app/views/pages/index.liquid").map(&:offense))
      end

      def test_workspace_edit
        # setup, pretend we ran diagnostics on a platformos_app
        diagnostics_manager = diagnose_platformos_app(
          SpaceInsideBraces.new,
          "app/views/pages/index.liquid" => <<~LIQUID
            {{x}}
            01234
          LIQUID
        )
        diagnostic_hashes = diagnostics_manager.diagnostics("app/views/pages/index.liquid").map(&:to_h)

        # pretend the user wants to correct all of them, what does the workspace_edit look like?
        workspace_edit = diagnostics_manager.workspace_edit(diagnostic_hashes)

        assert_equal(
          {
            documentChanges: [
              {
                textDocument: {
                  uri: diagnostic_hashes[0].dig(:data, :uri),
                  version: diagnostic_hashes[0].dig(:data, :version)
                },
                edits: [
                  { range: range(0, 2, 0, 2), newText: ' ' },
                  { range: range(0, 3, 0, 3), newText: ' ' }
                ]
              }
            ]
          },
          workspace_edit
        )
      end

      def test_delete_applied_deletes_fixable_diagnostics
        diagnostics_manager = diagnose_platformos_app(
          SpaceInsideBraces.new,
          TemplateLength.new(max_length: 0),
          "app/views/pages/index.liquid" => <<~LIQUID
            {{x}}
            01234
          LIQUID
        )
        diagnostics = diagnostics_manager.diagnostics("app/views/pages/index.liquid")

        refute(diagnostics.all? { |diagnostic| diagnostic.code == "SpaceInsideBraces" })

        diagnostics_manager.delete_applied(diagnostics.map(&:to_h))

        remaining_diagnostics = diagnostics_manager.diagnostics("app/views/pages/index.liquid")

        assert(
          remaining_diagnostics.all? { |diagnostic| diagnostic.code == "TemplateLength" },
          "TemplateLength is unfixable, therefore it should remain in the collection of diagnostics"
        )
      end

      def test_delete_applied_returns_updated_diagnostics
        diagnostics_manager = diagnose_platformos_app(
          SpaceInsideBraces.new,
          TemplateLength.new(max_length: 0),
          "app/views/pages/index.liquid" => <<~LIQUID
            {{x}}
            01234
          LIQUID
        )
        diagnostics = diagnostics_manager.diagnostics("app/views/pages/index.liquid")
        actual = diagnostics_manager.delete_applied(diagnostics.map(&:to_h))

        assert_equal(
          {
            "app/views/pages/index.liquid" => diagnostics.select { |d| d.code == "TemplateLength" }
          },
          actual.transform_keys(&:to_s)
        )
      end

      def test_delete_applied_returns_empty_diagnostics_if_all_were_cleared
        diagnostics_manager = diagnose_platformos_app(
          SpaceInsideBraces.new,
          "app/views/pages/index.liquid" => <<~LIQUID
            {{x}}
            01234
          LIQUID
        )
        diagnostics = diagnostics_manager.diagnostics("app/views/pages/index.liquid")
        actual = diagnostics_manager.delete_applied(diagnostics.map(&:to_h))

        assert_equal(
          {
            "app/views/pages/index.liquid" => []
          },
          actual.transform_keys(&:to_s)
        )
      end

      private

      def diagnose_platformos_app(*, templates)
        diagnostics_manager = PlatformosCheck::LanguageServer::DiagnosticsManager.new
        offenses = analyze_platformos_app(*, templates)
        diagnostics_manager.build_diagnostics(offenses)
        diagnostics_manager
      end

      def build_diagnostics(offenses:, analyzed_files: nil)
        actual_diagnostics = {}
        @diagnostics_manager.build_diagnostics(offenses, analyzed_files:).each do |path, diagnostics|
          actual_diagnostics[path] = diagnostics
        end
        actual_diagnostics
      end

      def assert_diagnostics(offenses:, analyzed_files:, diagnostics:)
        actual_diagnostics = build_diagnostics(offenses:, analyzed_files:)

        assert_equal(
          diagnostics,
          actual_diagnostics
            .transform_keys(&:to_s)
            .transform_values { |path_diagnostics| path_diagnostics.map(&:offense) }
        )
      end

      def range(start_row, start_col, end_row, end_col)
        {
          start: { line: start_row, character: start_col },
          end: { line: end_row, character: end_col }
        }
      end
    end
  end
end
