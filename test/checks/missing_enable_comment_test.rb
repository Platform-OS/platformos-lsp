# frozen_string_literal: true

require "test_helper"
require "minitest/focus"

class MissingEnableCommentTest < Minitest::Test
  def comment_types
    [
      ->(text) { "{% comment %}#{text}{% endcomment %}" },
      ->(text) { "{% # #{text} %}" }
    ]
  end

  def test_always_enabled_by_default
    refute_predicate(PlatformosCheck::MissingEnableComment.new, :can_disable?)
  end

  def test_no_default_noops
    comment_types.each do |comment|
      offenses = analyze_platformos_app(
        PlatformosCheck::MissingEnableComment.new,
        "app/views/pages/index.liquid" => <<~END
          #{comment.call('platformos-check-disable')}
          {% assign x = 1 %}
          #{comment.call('platformos-check-enable')}
        END
      )

      assert_offenses("", offenses)
    end
  end

  def test_first_line_comment_disables_entire_file
    comment_types.each do |comment|
      offenses = analyze_platformos_app(
        PlatformosCheck::MissingEnableComment.new,
        "app/views/pages/index.liquid" => <<~END
          #{comment.call('platformos-check-disable')}
          {% assign x = 1 %}
        END
      )

      assert_offenses("", offenses)
    end
  end

  def test_non_first_line_comment_triggers_offense
    comment_types.each do |comment|
      offenses = analyze_platformos_app(
        PlatformosCheck::MissingEnableComment.new,
        "app/views/pages/index.liquid" => <<~END
          <p>Hello, world</p>
          #{comment.call('platformos-check-disable')}
          {% assign x = 1 %}
        END
      )

      assert_offenses(<<~END, offenses)
        All checks were disabled but not re-enabled with platformos-check-enable at app/views/pages/index.liquid
      END
    end
  end

  def test_specific_checks_disabled
    comment_types.each do |comment|
      offenses = analyze_platformos_app(
        PlatformosCheck::MissingEnableComment.new,
        Minitest::Test::TracerCheck.new,
        "app/views/pages/index.liquid" => <<~END
          <p>Hello, world</p>
          #{comment.call('platformos-check-disable TracerCheck')}
          {% assign x = 1 %}
        END
      )

      assert_offenses(<<~END, offenses)
        TracerCheck was disabled but not re-enabled with platformos-check-enable at app/views/pages/index.liquid
      END
    end
  end

  def test_specific_checks_disabled_and_reenabled
    comment_types.each do |comment|
      offenses = analyze_platformos_app(
        PlatformosCheck::MissingEnableComment.new,
        Minitest::Test::TracerCheck.new,
        "app/views/pages/index.liquid" => <<~END
          <p>Hello, world</p>
          #{comment.call('platformos-check-disable TracerCheck, AnotherCheck')}
          {% assign x = 1 %}
        END
      )

      assert_offenses(<<~END, offenses)
        TracerCheck, AnotherCheck were disabled but not re-enabled with platformos-check-enable at app/views/pages/index.liquid
      END
    end
  end

  def test_specific_checks_disabled_and_reenabled_with_all_checks_disabled
    comment_types.each do |comment|
      offenses = analyze_platformos_app(
        PlatformosCheck::MissingEnableComment.new,
        Minitest::Test::TracerCheck.new,
        "app/views/pages/index.liquid" => <<~END
          <p>Hello, world</p>
          #{comment.call('platformos-check-disable TracerCheck, AnotherCheck')}
          {% assign x = 1 %}
          #{comment.call('platformos-check-disable')}
          {% assign x = 1 %}
        END
      )

      assert_offenses(<<~END, offenses)
        All checks were disabled but not re-enabled with platformos-check-enable at app/views/pages/index.liquid
      END
    end
  end
end
