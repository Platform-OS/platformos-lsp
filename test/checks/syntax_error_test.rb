# frozen_string_literal: true

require "test_helper"

class SyntaxErrorTest < Minitest::Test
  def test_reports_parse_errors
    offenses = analyze_platformos_app_without_raise(
      PlatformosCheck::SyntaxError.new,
      "app/views/pages/index.liquid" => <<~END
        {% include 'muffin'
      END
    )

    assert_offenses(<<~END, offenses)
      Tag '{%' was not properly terminated with regexp: /\\%\\}/ at app/views/pages/index.liquid:1
    END
  end

  def test_reports_missing_tag
    offenses = analyze_platformos_app_without_raise(
      PlatformosCheck::SyntaxError.new,
      "app/views/pages/index.liquid" => <<~END
        {% unknown %}
      END
    )

    assert_offenses(<<~END, offenses)
      Unknown tag 'unknown' at app/views/pages/index.liquid:1
    END
  end

  def test_reports_lax_warnings_and_continue
    offenses = analyze_platformos_app_without_raise(
      PlatformosCheck::SyntaxError.new,
      "app/views/pages/index.liquid" => <<~END
        {% if collection | size > 0 %}
        {% endif %}
        {% if collection | > 0 %}
        {% endif %}
      END
    )

    assert_offenses(<<~END, offenses)
      Expected end_of_string but found pipe at app/views/pages/index.liquid:1
      Expected end_of_string but found pipe at app/views/pages/index.liquid:3
    END
  end

  def test_invalid_render_tag
    offenses = analyze_platformos_app_without_raise(
      PlatformosCheck::SyntaxError.new,
      "app/views/pages/index.liquid" => "{% render ‘foo’ %}"
    )

    assert_offenses(<<~END, offenses)
      Syntax error in tag 'render' - Template name must be a quoted string at app/views/pages/index.liquid:1
    END
  end

  def test_invalid_parse_json_tag
    offenses = analyze_platformos_app_without_raise(
      PlatformosCheck::SyntaxError.new,
      "app/views/pages/index.liquid" => "{% parse_json %}{% endparse_json %}"
    )

    assert_offenses(<<~END, offenses)
      Syntax Error in 'parse_json' - Valid syntax: parse_json [var] at app/views/pages/index.liquid:1
    END
  end

  def test_invalid_inline_graphql_tag
    offenses = analyze_platformos_app_without_raise(
      PlatformosCheck::SyntaxError.new,
      "app/views/pages/index.liquid" => <<~END
        {% graphql name: name, category_id: category.id, lang: lang %}
          mutation create_category_detail(
            $category_id: String!
            $name: String!
            $lang: String!
          ) {
            record_create(
              record: {
                table: "category_detail"
                properties: [
                  { name: "category_id", value: $category_id }
                  { name: "name", value: $name }
                  { name: "lang", value: $lang }
                ]
              }
            ) {
              id
            }
          }
        {% endgraphql %}
      END
    )

    assert_offenses(<<~END, offenses)
      Invalid syntax for inline graphql tag - missing result name. Valid syntax: graphql result, arg1: var1, ... at app/views/pages/index.liquid:1
    END
  end
end
