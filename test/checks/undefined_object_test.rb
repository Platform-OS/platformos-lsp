# frozen_string_literal: true

require "test_helper"

class UndefinedObjectTest < Minitest::Test
  def test_report_on_undefined_variable
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        {{ price }}
      END
    )

    assert_offenses(<<~END, offenses)
      Undefined object `price` at app/views/pages/index.liquid:1
    END
  end

  def test_report_on_repeated_undefined_variable_on_different_lines
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        {{ price }}

        {{ price }}
      END
    )

    assert_offenses(<<~END, offenses)
      Undefined object `price` at app/views/pages/index.liquid:1
      Undefined object `price` at app/views/pages/index.liquid:3
    END
  end

  def test_report_on_undefined_global_object
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        {{ produt.title }}
      END
    )

    assert_offenses(<<~END, offenses)
      Undefined object `produt` at app/views/pages/index.liquid:1
    END
  end

  def test_report_on_undefined_global_object_argument
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        {{ form[email] }}
      END
    )

    assert_offenses(<<~END, offenses)
      Undefined object `email` at app/views/pages/index.liquid:1
      Undefined object `form` at app/views/pages/index.liquid:1
    END
  end

  def test_reports_several_offenses_for_same_object
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        {% if context[email] %}
          {{ context[email] }}
          {{ context[email] }}
        {% endif %}
      END
    )

    assert_offenses(<<~END, offenses)
      Undefined object `email` at app/views/pages/index.liquid:1
      Undefined object `email` at app/views/pages/index.liquid:2
      Undefined object `email` at app/views/pages/index.liquid:3
    END
  end

  def test_does_not_report_on_string_argument_to_global_object
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        {{ context["current_user"] }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_on_defined_variable
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        {% assign field = "session" %}
        {{ context[field] }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_on_defined_global_object
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        {{ context.current_user }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_on_assign
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        {% assign foo = "bar" %}
        {{ foo }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_on_capture
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        {% capture 'var' %}test string{% endcapture %}
        {{ var }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_on_forloops
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        {% assign some_array = '[{"name": "foo"}]' | parse_json %}
        {% for item in some_array %}
          {{ forloop.index }}: {{ item.name }}
        {% endfor %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_on_render_using_the_with_parameter
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% assign all_products = '{}' | parse_json %}
        {% assign featured_product = all_products['product_handle'] %}
        {% render 'product' with featured_product as my_product %}
      END
      "app/views/partials/product.liquid" => <<~END
        {{ my_product.available }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_on_render_using_the_for_parameter
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% assign variants = 'foo,bar' | split: ',' %}
        {% render 'variant' for variants as my_variant %}
      END
      "app/views/partials/variant.liquid" => <<~END
        {{ my_variant.price }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_report_on_render_with_variable_from_parent_context
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% assign price = "$3.00" %}
        {% render 'product' %}
      END
      "app/views/partials/product.liquid" => <<~END
        {{ price }}
      END
    )

    assert_offenses(<<~END, offenses)
      Missing argument `price` at app/views/pages/index.liquid:2
    END
  end

  def test_report_on_render_with_undefined_variable_as_argument
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        {% render 'product', price: adjusted_price %}
        {% render 'product', price: adjusted_price %}
      END
    )

    assert_offenses(<<~END, offenses)
      Undefined object `adjusted_price` at app/views/pages/index.liquid:1
      Undefined object `adjusted_price` at app/views/pages/index.liquid:2
    END
  end

  def test_does_not_report_on_render_with_variable_as_argument
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% assign adjusted_price = "$3.00" %}
        {% render 'product', price: adjusted_price %}
      END
      "app/views/partials/product.liquid" => <<~END
        {{ price }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_on_render_with_argument
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% render 'product', price: '$3.00' %}
      END
      "app/views/partials/product.liquid" => <<~END
        {{ price }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_report_on_render_with_undefined_argument
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% render 'product' %}
      END
      "app/views/partials/product.liquid" => <<~END
        {{ price }}
      END
    )

    assert_offenses(<<~END, offenses)
      Missing argument `price` at app/views/pages/index.liquid:1
    END
  end

  def test_report_on_render_with_repeated_undefined_attribute
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% render 'product' %}
      END
      "app/views/partials/product.liquid" => <<~END
        {{ price }}

        {{ price }}
      END
    )

    assert_offenses(<<~END, offenses)
      Missing argument `price` at app/views/pages/index.liquid:1
    END
  end

  def test_report_on_render_with_undefined_argument_in_one_of_multiple_locations
    sources = {
      "app/views/pages/index.liquid" => <<~END,
        <h1>Your product:</h1>
        <div class="product">{% render 'product' %}</div>
      END
      "app/views/pages/collection.liquid" => <<~END,
        {% render 'product', price: "3.00", currency: '$' %}
      END
      "app/views/partials/product.liquid" => <<~END
        {{ price | append: currency }}
      END
    }
    expected_sources = {
      "app/views/pages/index.liquid" => <<~END,
        <h1>Your product:</h1>
        <div class="product">{% render 'product', price: null, currency: null %}</div>
      END
      "app/views/pages/collection.liquid" => <<~END,
        {% render 'product', price: "3.00", currency: '$' %}
      END
      "app/views/partials/product.liquid" => <<~END
        {{ price | append: currency }}
      END

    }
    offenses = analyze_platformos_app(PlatformosCheck::UndefinedObject.new, sources)

    assert_offenses(<<~END, offenses)
      Missing argument `currency` at app/views/pages/index.liquid:2
      Missing argument `price` at app/views/pages/index.liquid:2
    END

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_fix_when_same_render_used_twice
    sources = {
      "app/views/pages/index.liquid" => <<~END,
        {% assign now = 'now' | to_time | strftime: '%Y-%m-%dT%H:%M:%S.%L%z' %}

        <form action="{% render 'link_to', text: context.params.object %}" method="post">
          <input type="hidden" name="authenticity_token" value="{{ context.authenticity_token }}">
          <input type="hidden" name="return_to" value="{% render 'link_to', anchor: "my_anchor" %}">
        </form>
      END
      "app/views/partials/link_to.liquid" => <<~END
        <a href="{{ url }}\#{{ anchor }}"><{{ text }}></a>
      END
    }
    expected_sources = {
      "app/views/pages/index.liquid" => <<~END,
        {% assign now = 'now' | to_time | strftime: '%Y-%m-%dT%H:%M:%S.%L%z' %}

        <form action="{% render 'link_to', text: context.params.object, url: null, anchor: null %}" method="post">
          <input type="hidden" name="authenticity_token" value="{{ context.authenticity_token }}">
          <input type="hidden" name="return_to" value="{% render 'link_to', anchor: "my_anchor", url: null, text: null %}">
        </form>
      END
      "app/views/partials/link_to.liquid" => <<~END
        <a href="{{ url }}\#{{ anchor }}"><{{ text }}></a>
      END
    }

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_fix_when_same_render_used_twice_in_liquid_blocks
    sources = {
      "app/views/pages/index.liquid" => <<~END,
        {% assign now = 'now' | to_time | strftime: '%Y-%m-%dT%H:%M:%S.%L%z' %}

        <form action="{% render 'link_to', text: context.params.object %}" method="post">
          <input type="hidden" name="authenticity_token" value="{{ context.authenticity_token }}">
          {% liquid
            print '<input type="hidden" name="return_to" value="'
            render 'link_to', anchor: "my_anchor"
            print '">'

            if true
              render 'link_to'
            else
              render 'link_to', url: "/"
            endif
          %}
        </form>
      END
      "app/views/partials/link_to.liquid" => <<~END
        <a href="{{ url }}\#{{ anchor }}"><{{ text }}></a>
      END
    }
    expected_sources = {
      "app/views/pages/index.liquid" => <<~END,
        {% assign now = 'now' | to_time | strftime: '%Y-%m-%dT%H:%M:%S.%L%z' %}

        <form action="{% render 'link_to', text: context.params.object, url: null, anchor: null %}" method="post">
          <input type="hidden" name="authenticity_token" value="{{ context.authenticity_token }}">
          {% liquid
            print '<input type="hidden" name="return_to" value="'
            render 'link_to', anchor: "my_anchor", url: null, text: null
            print '">'

            if true
              render 'link_to', url: null, anchor: null, text: null
            else
              render 'link_to', url: "/", anchor: null, text: null
            endif
          %}
        </form>
      END
      "app/views/partials/link_to.liquid" => <<~END
        <a href="{{ url }}\#{{ anchor }}"><{{ text }}></a>
      END
    }

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_report_on_render_with_undefined_argument_in_one_of_multiple_locations_in_single_file_mode_for_page
    offenses = analyze_single_file(
      "app/views/pages/index.liquid",
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% render 'product' %}
      END
      "app/views/pages/collection.liquid" => <<~END,
        {% render 'product', price: "$3.00" %}
      END
      "app/views/partials/product.liquid" => <<~END
        {{ price }}
      END
    )

    assert_offenses(<<~END, offenses)
      Missing argument `price` at app/views/pages/index.liquid:1
    END
  end

  def test_report_on_nested_render_with_undefined_argument_on_multi_file
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% render 'collection' %}
      END
      "app/views/partials/collection.liquid" => <<~END,
        {% render 'product' %}
      END
      "app/views/partials/product.liquid" => <<~END
        {{ price }}
      END
    )

    assert_offenses(<<~END, offenses)
      Missing argument `price` at app/views/partials/collection.liquid:1
    END
  end

  def test_does_not_report_on_nested_render_with_undefined_argument_on_single_file
    offenses = analyze_single_file(
      "app/views/pages/index.liquid",
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% render 'collection' %}
      END
      "app/views/partials/collection.liquid" => <<~END,
        {% render 'product' %}
      END
      "app/views/partials/product.liquid" => <<~END
        {{ price }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_on_nested_render_with_argument
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% render 'collection' %}
      END
      "app/views/partials/collection.liquid" => <<~END,
        {% render 'product', price: "$3.00" %}
      END
      "app/views/partials/product.liquid" => <<~END
        {{ price }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_on_unused_partial
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/partials/product.liquid" => <<~END
        {{ price }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_on_data_in_notifications
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/emails/customers/reset_password.liquid" => <<~END
        ---
        from: "{{ data.from }}"
        layout: mailer
        subject: "{{ data.subject }}"
        to: "{{ data.to }}"
        ---
        <p>{{ data.customer.name }}</p>
      END
    )

    assert_offenses("", offenses)
  end

  def test_reports_on_email_other_than_customers_reset_password
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END
        <p>{{ 'customer.reset_password.subtext' | t: email: email }}</p>
      END
    )

    assert_offenses(<<~END, offenses)
      Undefined object `email` at app/views/pages/index.liquid:1
    END
  end

  def test_does_not_report_on_pipe_default
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "layout/checkout.liquid" => <<~END
        {% assign obj = param | default: '' %}
        {% echo variable | default: '' %}
        {{ class | default: '' }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_recursion
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% render 'one' %}
      END
      "app/views/partials/one.liquid" => <<~END,
        {% render 'two' %}
      END
      "app/views/partials/two.liquid" => <<~END
        {% if some_end_condition %}
          {% render 'one' %}
        {% endif %}
      END
    )

    assert_offenses(<<~END, offenses)
      Missing argument `some_end_condition` at app/views/partials/one.liquid:1
    END
  end

  def test_recursion_with_duplicated_render
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/index.liquid" => <<~END,
        {% render 'one' %}
      END
      "app/views/partials/one.liquid" => <<~END,
        {% render 'two' %}
        {% render 'two', some_end_condition: true %}
        {% render 'two' %}
      END
      "app/views/partials/two.liquid" => <<~END
        {% if some_end_condition %}
          {% render 'one' %}
        {% endif %}
      END
    )

    assert_offenses(<<~END, offenses)
      Missing argument `some_end_condition` at app/views/partials/one.liquid:1
      Missing argument `some_end_condition` at app/views/partials/one.liquid:3
    END
  end

  def test_does_not_report_when_function_is_used
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function' %}
        {{ b }}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return 4 %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_report_unused_function_arg
    offenses = analyze_single_file(
      "app/views/partials/a.liquid",
      PlatformosCheck::UndefinedObject.new,
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function', not_used: "hello", used: "hi" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used %}
      END
    )

    assert_offenses(<<~END, offenses)
      Unused argument `not_used` at app/views/partials/a.liquid:1
    END
  end

  def test_fixes_unused_first_function_arg
    sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function', not_used: "hello", used: "hi", another_used: "ahoy" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }
    expected_sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function', used: "hi", another_used: "ahoy" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_fixes_block_unused_function_arg
    sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% liquid
         assign x = x | default: "a"
         function b = 'b_function', not_used: "hello", used: "hi"
        %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used %}
      END
    }
    expected_sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% liquid
         assign x = x | default: "a"
         function b = 'b_function', used: "hi"
        %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used %}
      END
    }

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_fixes_unused_first_function_arg_as_variable_without_space
    sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function', not_used:var, used: "hi", another_used: "ahoy" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }
    expected_sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function', used: "hi", another_used: "ahoy" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_fixes_unused_middle_function_arg
    sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function', used: "hi", not_used: "hello", another_used: "ahoy" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }
    expected_sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function', used: "hi", another_used: "ahoy" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_fixes_unused_last_function_arg
    sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function', used: "hi", another_used: "ahoy", not_used: "hello" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }
    expected_sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function', used: "hi", another_used: "ahoy" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_fixes_unused_first_function_arg_without_comma
    sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function', not_used: "hello", used: "hi", another_used: "ahoy" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }
    expected_sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function', used: "hi", another_used: "ahoy" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_fixes_unused_middle_function_arg_without_comma
    sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function' used: "hi" not_used: "hello" another_used: "ahoy" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }
    expected_sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function' used: "hi" another_used: "ahoy" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_fixes_unused_last_function_arg_without_comma
    sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function' used: "hi" another_used: "ahoy" not_used: "hello" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }
    expected_sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function' used: "hi" another_used: "ahoy" %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return used | append: another_used %}
      END
    }

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_does_not_report_argument_provided_to_function
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/a.liquid" => <<~END,
        {% function b = 'b_function', my_arg: "Hello" %}
        {{ b }}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return my_arg %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_report_on_undefined_function_argument
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/a.liquid" => <<~END,
        {% function b = 'b_function' %}
        {{ b }}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return my_arg %}
      END
    )

    assert_offenses(<<~END, offenses)
      Missing argument `my_arg` at app/views/pages/a.liquid:1
    END
  end

  def test_report_on_undefined_function_argument_for_all_invocations
    skip "Not supported yet"
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/a.liquid" => <<~END,
        {% function b = 'b_function' %}
        {% function b = 'b_function', my_arg: 10 %}
        {% function b = 'b_function' %}
        {% function b = 'b_function' %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return my_arg %}
      END
    )

    assert_offenses(<<~END, offenses)
      Missing argument `my_arg` at app/views/pages/a.liquid:1
      Missing argument `my_arg` at app/views/pages/a.liquid:3
      Missing argument `my_arg` at app/views/pages/a.liquid:4
    END
  end

  def test_report_on_undefined_function_argument_for_partials
    sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function' %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return my_arg %}
      END
    }
    expected_sources = {
      "app/views/partials/a.liquid" => <<~END,
        {% function b = 'b_function', my_arg: null %}
      END
      "app/lib/b_function.liquid" => <<~END
        {% return my_arg %}
      END
    }
    offenses = analyze_platformos_app(PlatformosCheck::UndefinedObject.new, sources)

    assert_offenses(<<~END, offenses)
      Missing argument `my_arg` at app/views/partials/a.liquid:1
    END

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_does_not_report_on_default_function_argument
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/a.liquid" => <<~END,
        {% function b = 'b_function' %}
        {{ b }}
      END
      "app/lib/b_function.liquid" => <<~END
        {% assign my_arg = my_arg | default: nil %}
        {% return my_arg %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_when_graphql_is_used
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/partials/a.liquid" => <<~END
        {% graphql a %}
          query records {
            records(per_page: 20, table: "my_table") {
              results {
                id
              }
            }
          }
        {% endgraphql %}
        {{ a }}
        {% graphql b = 'my_query' %}
        {{ b }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_report_when_argument_not_explicitly_provided_to_background_partial_syntax
    sources = {
      "app/views/pages/a.liquid" => <<~END,
        {% background res = 'my_background', arg: "hello", delay: 3.5 %}
        {{ res }}
      END
      "app/views/partials/my_background.liquid" => <<~END
        {{ arg }} {{ arg2 }}
      END
    }

    expected_sources = {
      "app/views/pages/a.liquid" => <<~END,
        {% background res = 'my_background', arg: "hello", delay: 3.5, arg2: null %}
        {{ res }}
      END
      "app/views/partials/my_background.liquid" => <<~END
        {{ arg }} {{ arg2 }}
      END
    }
    offenses = analyze_platformos_app(PlatformosCheck::UndefinedObject.new, sources)

    assert_offenses(<<~END, offenses)
      Missing argument `arg2` at app/views/pages/a.liquid:1
    END

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_report_when_argument_not_explicitly_provided_to_background_inline_syntax
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/a.liquid" => <<~END
        {% background source_name: 'my_background', arg: "hello", arg3: arg3, delay: 3.5 %}
          {{ arg }}
        {% endbackground %}
      END
    )

    assert_offenses(<<~END, offenses)
      Undefined object `arg3` at app/views/pages/a.liquid:1
    END
  end

  def test_report_when_graphql_argument_not_defined_via_function
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/pages/a.liquid" => <<~END,
        {% function user = 'queries/user/find' %}
        {{ user }}
      END
      "app/views/partials/queries/user/find.liquid" => <<~END
        {% graphql res = 'user/find', user_id: user_id %}
        {% return res %}
      END
    )

    assert_offenses(<<~END, offenses)
      Missing argument `user_id` at app/views/pages/a.liquid:1
    END
  end

  def test_does_not_report_when_parse_json_is_used
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/views/partials/a.liquid" => <<~END
        {% parse_json x %}
          { "hello": "world" }
        {% endparse_json %}
        {{ x }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_report_when_undefined_object_used_inside_parse_json
    sources = {
      "app/views/pages/a.liquid" => <<~END,
        {% function b = 'command/b_function' %}
        {{ b }}
      END
      "app/views/partials/command/b_function.liquid" => <<~END,
        {% function res = 'command/b_function/build', uuid: "Hello", type: "World" %}
        {% return res %}
      END
      "app/views/partials/command/b_function/build.liquid" => <<~END
        {% parse_json object %}
          {
            "uuid": {{ uuid | json }},
            "type": {{ type | json }},
            "ids":  {{ ids | json }}
          }
        {% endparse_json %}
        {% return object %}
      END
    }
    expected_sources = {
      "app/views/pages/a.liquid" => <<~END,
        {% function b = 'command/b_function' %}
        {{ b }}
      END
      "app/views/partials/command/b_function.liquid" => <<~END,
        {% function res = 'command/b_function/build', uuid: "Hello", type: "World", ids: null %}
        {% return res %}
      END
      "app/views/partials/command/b_function/build.liquid" => <<~END
        {% parse_json object %}
          {
            "uuid": {{ uuid | json }},
            "type": {{ type | json }},
            "ids":  {{ ids | json }}
          }
        {% endparse_json %}
        {% return object %}
      END
    }
    offenses = analyze_platformos_app(PlatformosCheck::UndefinedObject.new, sources)

    assert_offenses(<<~END, offenses)
      Missing argument `ids` at app/views/partials/command/b_function.liquid:1
    END

    fix_platformos_app(PlatformosCheck::UndefinedObject.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_does_not_report_undefined_object_response_inside_callback_in_notification
    offenses = analyze_platformos_app(
      PlatformosCheck::UndefinedObject.new,
      "app/api_calls/example_call.liquid" => <<~END
        ---
         to: 'https://example.com/{{ data.script_name }}'
         request_type: POST
         callback: >
           {% log response, type: 'defined object' %}
         headers: >
           {
             "Content-Type": "application/x-www-form-urlencoded"
           }
         ---
         {{ data.request_body }}
      END
    )

    assert_offenses("", offenses)
  end
end
