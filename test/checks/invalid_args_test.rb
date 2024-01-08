# frozen_string_literal: true

require "test_helper"

class InvalidArgsTest < Minitest::Test
  def test_report_all_duplicated_argument_in_render
    offenses = analyze_platformos_app(
      PlatformosCheck::InvalidArgs.new,
      "app/views/pages/index.liquid" => <<~END
        {% render "my-partial", var: "hello", another: 6, arg: 1, arg: 2, another: 4 %}
      END
    )

    assert_offenses(<<~END, offenses)
      Duplicated argument `another` at app/views/pages/index.liquid:1
      Duplicated argument `arg` at app/views/pages/index.liquid:1
    END
  end

  def test_fixes_duplicate_argument_in_render
    sources = {
      "app/views/pages/index.liquid" => <<~END
        {% render "my-partial", var: "hello", another: 6, another: 4 %}
      END
    }
    expected_sources = {
      "app/views/pages/index.liquid" => <<~END
        {% render "my-partial", var: "hello", another: 4 %}
      END
    }

    fix_platformos_app(PlatformosCheck::InvalidArgs.new, sources).each do |path, source|
      assert_equal(expected_sources[path], source)
    end
  end

  def test_report_all_duplicated_argument_in_function
    offenses = analyze_platformos_app(
      PlatformosCheck::InvalidArgs.new,
      "app/views/pages/index.liquid" => <<~END
        {% function res = "my-partial", var: "hello", another: 6, arg: 1, arg: 2, another: 4 %}
      END
    )

    assert_offenses(<<~END, offenses)
      Duplicated argument `another` at app/views/pages/index.liquid:1
      Duplicated argument `arg` at app/views/pages/index.liquid:1
    END
  end

  def test_query_unknown_argument
    offenses = render_query_graphql('{% graphql res = "records/search", id: 10, page: 2, invalid: "Hey", key: "hello" %}')

    assert_offenses(<<~END, offenses)
      Undefined argument `invalid` provided to `app/graphql/records/search.graphql` at app/views/pages/index.liquid:1
    END
  end

  def test_query_duplicated_argument
    offenses = render_query_graphql('{% graphql res = "records/search", id: 10, id: 11 %}')

    assert_offenses(<<~END, offenses)
      Duplicated argument `id` at app/views/pages/index.liquid:1
      Required argument `key` not provided to `app/graphql/records/search.graphql` at app/views/pages/index.liquid:1
    END
  end

  def test_mutation_unknown_argument
    offenses = render_mutation_graphql('{% graphql res = "dummy/create", name: "John", creator_id: 1, coment: "Whopse, typo" %}')

    assert_offenses(<<~END, offenses)
      Undefined argument `coment` provided to `app/graphql/dummy/create.graphql` at app/views/pages/index.liquid:1
    END
  end

  def test_query_does_not_report_valid_arguments
    offenses = render_query_graphql('{% graphql res = "records/search", id: 10, page: 2, key: "hello" %}')

    assert_offenses("", offenses)
  end

  def test_mutation_does_not_report_valid_arguments
    offenses = render_mutation_graphql('{% graphql res = "dummy/create", name: "John", creator_id: 1, comment: "Hello" %}')

    assert_offenses("", offenses)
  end

  def test_query_does_not_report_when_using_args
    offenses = render_query_graphql('{% graphql res = "records/search", args: id: 10, page: 2, key: "hello" %}')

    assert_offenses("", offenses)
  end

  def test_mutation_does_not_report_when_using_args
    offenses = render_mutation_graphql('{% graphql res = "dummy/create", args: name: "John", creator_id: 1, comment: "Hello" %}')

    assert_offenses("", offenses)
  end

  def test_query_not_providing_required_argument
    offenses = render_query_graphql('{% graphql res = "records/search", page: 10 %}')

    assert_offenses(<<~END, offenses)
      Required argument `id` not provided to `app/graphql/records/search.graphql` at app/views/pages/index.liquid:1
      Required argument `key` not provided to `app/graphql/records/search.graphql` at app/views/pages/index.liquid:1
    END
  end

  def test_mutation_not_providing_required_argument
    offenses = render_mutation_graphql('{% graphql res = "dummy/create" %}')

    assert_offenses(<<~END, offenses)
      Required argument `creator_id` not provided to `app/graphql/dummy/create.graphql` at app/views/pages/index.liquid:1
      Required argument `name` not provided to `app/graphql/dummy/create.graphql` at app/views/pages/index.liquid:1
    END
  end

  def test_query_parsing_error
    offenses = analyze_platformos_app(
      PlatformosCheck::InvalidArgs.new,
      "app/views/pages/index.liquid" => '{% graphql res = "records/search", key: "hello" %}',
      "app/graphql/records/search.graphql" => <<~END
              query search(
          $id: ID!,
          $limit: Int = 20,
          $page: Int = 1,
           {
          records(
            per_page: $limit
            page: page
            filter: {
              id: { value: $id }
              table: { value: "records" }
              properties: [
                { name: "key", value: $key },
                ]
            }
          ) {
            total_entries
            total_pages
            has_previous_page
            has_next_page
            results {
              id
              key: property(name: "key")
            }
        }

      END
    )

    assert_offenses(<<~END, offenses)
      GraphQL Parse error triggered by `app/graphql/records/search.graphql`: Parse error on "{" (LCURLY) at [5, 4] at app/views/pages/index.liquid:1
    END
  end

  def test_query_does_not_crash_when_fragments_used
    offenses = analyze_platformos_app(
      PlatformosCheck::InvalidArgs.new,
      "app/views/pages/index.liquid" => <<~END,
        {%- graphql approval = 'modules/admin/api/records/get',
          id: context.params.id,
          with_dependants: with_dependants
          | dig: 'records', 'results'
          | first
        -%}
      END
      "modules/admin/public/graphql/api/records/get.graphql" => <<~END
        fragment UserFields on User {
          id
          email
          first_name: property(name: "first_name")
          last_name: property(name: "last_name")
          slug: property(name: "slug")
        }

        query get($id: ID, $user_id: String, $with_dependants: Boolean = false) {
          records(
            per_page: 1
            filter: {
              id: { value: $id }
              table: { value: "approval" }
              properties: [{ name: "user_id", value: $user_id }]
            }
          ) {
            results {
              id
              background_checked_by: related_user(
                join_on_property: "background_checked_by"
              ) {
                ...UserFields
              }
              final_background_checked_by: related_user(
                join_on_property: "final_background_checked_by"
              ) {
                ...UserFields
              }
            }
          }
        }
      END
    )

    assert_offenses("", offenses)
  end

  def test_query_does_not_crash_when_chaining_filters
    offenses = analyze_platformos_app(
      PlatformosCheck::InvalidArgs.new,
      "app/views/pages/index.liquid" => <<~END,
        {%- graphql _g = 'modules/admin/api/records/get', id: context.params.id | fetch: 'records' | fetch: 'results' -%}
      END
      "modules/admin/public/graphql/api/records/get.graphql" => <<~END
        query get($id: ID) {
          records(
            per_page: 1
            filter: {
              id: { value: $id }
              table: { value: "records" }
            }
          ) {
            results {
              id
            }
          }
        }
      END
    )

    assert_offenses("", offenses)
  end

  private

  def render_query_graphql(graphql_tag)
    analyze_platformos_app(
      PlatformosCheck::InvalidArgs.new,
      "app/views/pages/index.liquid" => graphql_tag,
      "app/graphql/records/search.graphql" => <<~END
              query search(
          $id: ID!,
          $limit: Int = 20,
          $page: Int = 1,
          $key: String!,
          ) {
          records(
            per_page: $limit
            page: $page
            filter: {
              id: { value: $id }
              table: { value: "records" }
              properties: [
                { name: "key", value: $key },
                ]
            }
          ) {
            total_entries
            total_pages
            has_previous_page
            has_next_page
            results {
              id
              key: property(name: "key")
            }
          }
        }

      END
    )
  end

  def render_mutation_graphql(graphql_tag)
    analyze_platformos_app(
      PlatformosCheck::InvalidArgs.new,
      "app/views/pages/index.liquid" => graphql_tag,
      "app/graphql/dummy/create.graphql" => <<~END
        mutation dummy_create(
          $name: String!
          $creator_id: String!
          $comment: String
        ) {
          record: record_create(
            record: {
              table: "dummy"
              properties: [
                { name: "name" value: $name }
                { name: "creator_id" value: $creator_id }
                { name: "comment" value: $comment }
              ]
            }
          ){
            id
            created_at
            deleted_at
            type: table

            name: property(name: "name")
            comment: property(name: "comment")
            creator_id: property(name: "creator_id")
          }
        }
      END
    )
  end
end
