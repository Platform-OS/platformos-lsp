# frozen_string_literal: true

require 'graphql'

module PlatformosCheck
  class GraphqlFile < AppFile
    DIR_PREFIX = %r{\A/?((marketplace_builder|app)/(graph_queries|graphql)s?/|modules/((\w|-)*)/(private|public)/(graph_queries|graphql)s?/)}

    def write
      content = rewriter.to_s
      return unless source != content

      @storage.write(@relative_path, content.gsub("\n", @eol))
      @source = content
      @rewriter = nil
      @ast = nil
      @variables = nil
      @definition = nil
      @parse = nil
      @required_arguments = nil
      @defined_arguments = nil
    end

    def rewriter
      @rewriter ||= AppFileRewriter.new(@relative_path, source)
    end

    def dir_prefix
      DIR_PREFIX
    end

    def source_excerpt(line)
      original_lines = source.split("\n")
      original_lines[bounded(0, line - 1, original_lines.size - 1)].strip
    rescue StandardError => e
      PlatformosCheck.bug(<<~EOS)
        Exception while running `source_excerpt(#{line})`:
        ```
        #{e.class}: #{e.message}
          #{e.backtrace.join("\n  ")}
        ```

        path: #{path}

        source:
        ```
        #{source}
        ```
      EOS
    end

    def parse
      @parse ||= GraphQL.parse(source)
    end

    def warnings
      parse.warnings
    end

    def root
      parse.root
    end

    def self.parse(_source)
      Struct.new(:warnings, :root)
    end

    def required_arguments
      @required_arguments ||= variables.each_with_object([]) do |v, vars|
        vars << v.name if v.type.is_a?(GraphQL::Language::Nodes::NonNullType)
      end
    end

    def optional_arguments
      @optional_arguments ||= defined_arguments - required_arguments
    end

    def defined_arguments
      @defined_arguments ||= variables.map(&:name)
    end

    def selections
      definition.selections
    end

    def fragments
      @fragments ||= parse.definitions.select { |d| d.is_a?(GraphQL::Language::Nodes::FragmentDefinition) }
    end

    private

    def variables
      @variables ||= definition&.variables || []
    end

    def definition
      @definition ||= parse.definitions.detect { |d| d.is_a?(GraphQL::Language::Nodes::OperationDefinition) }
    end

    def bounded(lower, x, upper)
      [lower, [x, upper].min].max
    end
  end
end
