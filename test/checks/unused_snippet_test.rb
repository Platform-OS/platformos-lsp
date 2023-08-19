# frozen_string_literal: true

require "test_helper"

class UnusedSnippetTest < Minitest::Test
  def test_finds_unused
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedSnippet.new,
      "templates/index.liquid" => <<~END,
        {% include 'muffin' %}
      END
      "snippets/muffin.liquid" => <<~END,
        Here's a muffin
      END
      "snippets/unused.liquid" => <<~END
        This is not used
      END
    )

    assert_offenses(<<~END, offenses)
      This snippet is not used at snippets/unused.liquid
    END
  end

  def test_ignores_dynamic_includes
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedSnippet.new,
      "templates/index.liquid" => <<~END,
        {% assign name = 'muffin' %}
        {% include name %}
      END
      "snippets/muffin.liquid" => <<~END,
        Here's a muffin
      END
      "snippets/unused.liquid" => <<~END
        This is not used
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_turn_off_the_check_because_of_potential_render_block
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedSnippet.new,
      "templates/index.liquid" => <<~END,
        {% for name in section.blocks %}
          {% render name %}
        {% endfor %}
      END
      "snippets/unused.liquid" => <<~END
        This is not used
      END
    )

    assert_offenses(<<~END, offenses)
      This snippet is not used at snippets/unused.liquid
    END
  end

  def test_does_turn_off_the_check_because_of_dynamic_include_in_for_loop
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedSnippet.new,
      "templates/index.liquid" => <<~END,
        {% for name in includes %}
          {% include name %}
        {% endfor %}
      END
      "snippets/unused.liquid" => <<~END
        This is not used
      END
    )

    assert_offenses("", offenses)
  end

  def test_removes_unused_snippets
    platformos_app = make_platformos_app(
      "templates/index.liquid" => <<~END,
        {% include 'muffin' %}
      END
      "snippets/muffin.liquid" => <<~END,
        Here's a muffin
      END
      "snippets/unused.liquid" => <<~END
        This is not used
      END
    )

    analyzer = PlatformosCheck::Analyzer.new(platformos_app, [PlatformosCheck::UnusedSnippet.new], true)
    analyzer.analyze_platformos_app
    analyzer.correct_offenses

    refute_includes(platformos_app.storage.files, "snippets/unused.liquid")
  end
end
