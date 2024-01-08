# frozen_string_literal: true

require "test_helper"

class UnusedAssignTest < Minitest::Test
  def test_reports_unused_assigns
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% assign x = 1 %}
      END
    )

    assert_offenses(<<~END, offenses)
      `x` is never used at app/views/partials/index.liquid:1
    END
  end

  def test_do_not_reports_unused_assigns_if_starts_with_underscore
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% assign _x = 'foo' %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_do_not_reports_unused_assigns_if_modifies_object
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% assign result = arr | array_add: el %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_do_not_reports_unused_assigns_if_modifies_object_in_chain
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% assign result = arr | array_compact | array_add: el %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_reports_unused_function_assigns
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% function x = 'my_partial' %}
      END
    )

    assert_offenses(<<~END, offenses)
      `x` is never used at app/views/partials/index.liquid:1
    END
  end

  def test_reports_unused_parse_json
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% parse_json x %}
          { "hello": "world" }
        {% endparse_json %}
      END
    )

    assert_offenses(<<~END, offenses)
      `x` is never used at app/views/partials/index.liquid:1
    END
  end

  def test_reports_unused_graphql_query_assigns
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% graphql x = 'my_query', arg: 'hello', arg2: 'world' | dig: 'resulsts' | map: 'id' %}
      END
    )

    assert_offenses(<<~END, offenses)
      `x` is never used at app/views/partials/index.liquid:1
    END
  end

  def test_does_not_report_when_var_used_as_graphql_partial_name
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% assign partial = "my-partial" %}
        {% graphql _x = partial, arg: 10 %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_does_not_report_unused_variable_in_inline_graphql
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => ''
    )

    assert_offenses("", offenses)
  end

  def test_do_not_reports_unused_function_assigns_if_starts_with_underscore
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% function _x = 'my_partial' %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_do_not_reports_unused_assign_if_used_in_hash_assign
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% assign data = '{}' | parse_json %}
        {% hash_assign data['id'] = "hello" %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_do_not_reports_unused_function_assigns_if_useed_in_another_function_call
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% assign var = "hello" %}
        {% function _x = 'my_partial', hello: var %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_do_not_report_used_assigns
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% assign a = 1 %}
        {{ a }}
        {% assign b = 1 %}
        {{ 'a' | t: b }}
        {% assign c = 1 %}
        {{ 'a' | t: tags: c }}
        {% liquid
         assign d = 1
         render 'foo' with d
         assign e = "01234" | split: ""
         render 'foo' for e as item
         assign g = "hello"
         print g
         assign h = "my log"
         log h, type: 'warning'
         assign i = "key"
         assign j = "val"
         assign hash = '{}' | parse_json
         hash_assign hash[i] = "val"
         hash_assign hash['key'] = j
         assign cache_key = 'my-key'
         assign expire_time = 10
         cache cache_key, expire: expire_time
         endcache
         assign graph_arg = 10
         graphql res = 'my_query', arg: graph_arg
         echo res
         echo hash
         assign url = '/my-page'
         assign session_var = 'val'
         session key = session_var
         assign global_var = 'global'
         export global_var, namespace: 'globals'
         redirect_to url
         assign u_id = 25
         sign_in user_id: u_id
         assign strategy = 'hcaptcha'
         spam_protection strategy
         assign f = "val"
         return f
        %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_error; end

  def test_do_not_report_used_assigns_bracket_syntax
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% liquid
          assign resource = request.page_type
          assign meta_value = [resource].metafields.namespace.key
          echo meta_value
        %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_do_not_report_assigns_used_before_defined
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% unless a %}
          {% assign a = 1 %}
        {% endunless %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_do_not_report_assigns_used_in_includes
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END,
        {% assign a = 1 %}
        {% include 'using' %}
      END
      "app/views/partials/using.liquid" => <<~END
        {{ a }}
      END
    )

    assert_offenses("", offenses)
  end

  def test_recursion_in_includes
    offenses = analyze_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END,
        {% assign a = 1 %}
        {% include 'one' %}
      END
      "app/views/partials/one.liquid" => <<~END,
        {% include 'two' %}
        {{ a }}
      END
      "app/views/partials/two.liquid" => <<~END
        {% if some_end_condition %}
          {% include 'one' %}
        {% endif %}
      END
    )

    assert_offenses("", offenses)
  end

  def test_removes_unused_assign
    expected_sources = {
      "app/views/partials/index.liquid" => "\n"
    }
    sources = fix_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% assign x = 1 %}
      END
    )

    sources.each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_removes_unused_assign_liquid_block
    expected_sources = {
      "app/views/partials/index.liquid" => <<~END
        {% liquid
          assign x = 1
          assign y = 2
        %}
        {{ x }}
        {{ y }}
      END
    }
    sources = fix_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% liquid
          assign x = 1
          assign y = 2
          assign z = 3
        %}
        {{ x }}
        {{ y }}
      END
    )

    sources.each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_removes_unused_assign_middle_of_line
    expected_sources = {
      "app/views/partials/index.liquid" => <<~END
        <p>test case</p><p>test case</p>
      END
    }
    sources = fix_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        <p>test case</p>{% assign x = 1 %}<p>test case</p>
      END
    )

    sources.each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_removes_unused_assign_leaves_html
    expected_sources = {
      "app/views/partials/index.liquid" => <<~END
        <p>test case</p>
      END
    }
    sources = fix_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        <p>test case</p>{% assign x = 1 %}
      END
    )

    sources.each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_rename_unused_function_assign
    expected_sources = {
      "app/views/partials/index.liquid" => "{% function _x = 'my_func' %}\n"
    }
    sources = fix_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% function x = 'my_func' %}
      END
    )

    sources.each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_rename_unused_function_assign_liquid_block
    expected_sources = {
      "app/views/partials/index.liquid" => <<~END
        {% liquid
          function x = 'my_func'
          function y = 'my_func2'
          function _z = 'my_func3'
        %}
        {{ x }}
        {{ y }}
      END
    }
    sources = fix_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% liquid
          function x = 'my_func'
          function y = 'my_func2'
          function z = 'my_func3'
        %}
        {{ x }}
        {{ y }}
      END
    )

    sources.each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_rename_unused_function_assign_middle_of_line
    expected_sources = {
      "app/views/partials/index.liquid" => <<~END
        <p>test function assign case</p>{%    function    _x = 'my_func' %}<p>test case</p>
      END
    }
    sources = fix_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        <p>test function assign case</p>{%    function    x = 'my_func' %}<p>test case</p>
      END
    )

    sources.each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_removes_unused_function_assign_leaves_html
    expected_sources = {
      "app/views/partials/index.liquid" => <<~END
        <p>test case</p>{%   function   _x   = 'my_func' %}
      END
    }
    sources = fix_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        <p>test case</p>{%   function   x   = 'my_func' %}
      END
    )

    sources.each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_rename_unused_graphql_assign
    expected_sources = {
      "app/views/partials/index.liquid" => "{% graphql _x = 'my-mutation' %}\n"
    }
    sources = fix_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% graphql x = 'my-mutation' %}
      END
    )

    sources.each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_removes_unused_graphql_assign_leaves_html
    expected_sources = {
      "app/views/partials/index.liquid" => <<~END
        <p>test case</p>{% graphql _x = 'my-mutation' %}
      END
    }
    sources = fix_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        <p>test case</p>{% graphql x = 'my-mutation' %}
      END
    )

    sources.each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_removes_unused_graphql_and_function_inside_liquid
    expected_sources = {
      "app/views/partials/index.liquid" => <<~END
        {% liquid
          print "Hello"
          graphql _g = 'my-mutation', arg: 10 | dig: 'results'

          function _f = 'my_partial', arg2: "World", name: "John"

          echo "World"
        %}
          <p>test case</p>
      END
    }
    sources = fix_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% liquid
          print "Hello"
          graphql g = 'my-mutation', arg: 10 | dig: 'results'

          function f = 'my_partial', arg2: "World", name: "John"

          echo "World"
        %}
          <p>test case</p>
      END
    )

    sources.each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_rename_unused_background_assign
    expected_sources = {
      "app/views/partials/index.liquid" => "{% background _x = 'my/background/job' %}\n"
    }
    sources = fix_platformos_app(
      PlatformosCheck::UnusedAssign.new,
      "app/views/partials/index.liquid" => <<~END
        {% background x = 'my/background/job' %}
      END
    )

    sources.each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end
end
