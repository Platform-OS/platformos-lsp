# frozen_string_literal: true

module PlatformosCheck
  module Tags
    class Graphql < Base
      QUERY_NAME_SYNTAX = /(#{Liquid::VariableSignature}+)\s*=\s*(.*)\s*/om
      INLINE_SYNTAX = /(#{Liquid::QuotedFragment}+)(\s*(#{Liquid::QuotedFragment}+))?/o
      INLINE_SYNTAX_WITHOUT_RESULT_VARIABLE = /\A([\w\-\.\[\]])+\s*:\s*/om
      CLOSE_TAG_SYNTAX = /\A(.*)(?-mix:\{%-?)\s*(\w+)\s*(.*)?(?-mix:%\})\z/m # based on Liquid::Raw::FullTokenPossiblyInvalid

      attr_reader :to, :from, :inline_query, :value_expr, :partial_name, :attributes_expr, :attributes

      def initialize(tag_name, markup, options)
        super
        if markup =~ QUERY_NAME_SYNTAX
          @to = Regexp.last_match(1)
          @inline_query = false

          # inline query looks like this:
          # {% graph res = "my_query", id: "1" | dig: 'my_query' %}
          # we want to first process "my_query, id: "1" , store it in "res" and then process
          # it with filters like this:
          # res | dig: 'my_query'
          after_assign_markup = Regexp.last_match(2).split('|')
          parse_markup(tag_name, after_assign_markup.shift)
          @attributes = attributes_expr.keys

          after_assign_markup.unshift(@to)
          @partial_name = value_expr
          @from = Liquid::Variable.new(after_assign_markup.join('|'), options)
        elsif INLINE_SYNTAX.match?(markup)
          raise Liquid::SyntaxError, 'Invalid syntax for inline graphql tag - missing result name. Valid syntax: graphql result, arg1: var1, ...' if markup.match?(INLINE_SYNTAX_WITHOUT_RESULT_VARIABLE)

          @inline_query = true
          parse_markup(tag_name, markup)
          @attributes = attributes_expr.keys
          @to = @value_expr.is_a?(String) ? @value_expr : @value_expr.name
        else
          raise Liquid::SyntaxError, 'Invalid syntax for graphql tag'
        end
      end

      def parse(tokens)
        return super unless @inline_query

        @body = +''
        while (token = tokens.send(:shift))
          if token =~ CLOSE_TAG_SYNTAX && block_delimiter == Regexp.last_match(2)
            @body << Regexp.last_match(1) if Regexp.last_match(1) != ''
            return
          end
          @body << token unless token.empty?
        end

        raise Liquid::SyntaxError, parse_context.locale.t('errors.syntax.tag_never_closed', block_name:)
      end

      def block_name
        @tag_name
      end

      def block_delimiter
        @block_delimiter = "end#{block_name}"
      end

      class ParseTreeVisitor < Liquid::ParseTreeVisitor
        def children
          [@node.to, @node.partial_name].compact + @node.attributes_expr.values
        end
      end
    end
  end
end
