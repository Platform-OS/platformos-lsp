# frozen_string_literal: true

module PlatformosCheck
  class UndefinedObject < LiquidCheck
    category :liquid
    doc docs_url(__FILE__)
    severity :error

    NOTIFICATION_GLOBAL_OBJECTS = %w[data response form].freeze
    FORM_GLOBAL_OBJECTS = %w[form form_builder].freeze

    class TemplateInfo
      def initialize(app_file: nil)
        @all_variable_lookups = {}
        @all_assigns = {}
        @all_captures = {}
        @all_forloops = {}
        @all_renders = {}
        @app_file = app_file
      end

      attr_reader :all_assigns, :all_captures, :all_forloops, :app_file, :all_renders

      def add_render(name:, node:)
        @all_renders[name] ||= []
        @all_renders[name] << node
      end

      def add_variable_lookup(name:, node:)
        parent = node
        line_number = nil
        loop do
          line_number = parent.line_number
          parent = parent.parent
          break unless line_number.nil? && parent
        end
        key = [name, line_number]
        @all_variable_lookups[key] = node
      end

      def all_variables
        all_assigns.keys + all_captures.keys + all_forloops.keys
      end

      def each_partial
        @all_renders.each do |(name, nodes)|
          nodes.each do |node|
            yield [name, node]
          end
        end
      end

      def each_variable_lookup(unique_keys = false)
        seen = Set.new
        @all_variable_lookups.each do |(key, info)|
          name, _line_number = key

          next if unique_keys && seen.include?(name)

          seen << name

          yield [key, info]
        end
      end
    end

    def self.single_file(**_args)
      true
    end

    def initialize(config_type: :default)
      @config_type = config_type
      @files = {}
    end

    def on_document(node)
      @files[node.app_file.name] = TemplateInfo.new(app_file: node.app_file)
    end

    def on_assign(node)
      @files[node.app_file.name].all_assigns[node.value.to] = node
    end

    def on_capture(node)
      @files[node.app_file.name].all_captures[node.value.instance_variable_get(:@to)] = node
    end

    def on_parse_json(node)
      @files[node.app_file.name].all_captures[node.value.to] = node
    end

    def on_for(node)
      @files[node.app_file.name].all_forloops[node.value.variable_name] = node
    end

    def on_include(_node)
      # NOOP: we purposely do nothing on `include` since it is deprecated
    end

    def on_render(node)
      return unless node.value.template_name_expr.is_a?(String)

      partial_name = node.value.template_name_expr
      @files[node.app_file.name].add_render(
        name: partial_name,
        node:
      )
    end

    def on_function(node)
      @files[node.app_file.name].all_assigns[node.value.to] = node

      return unless node.value.from.is_a?(String)

      @files[node.app_file.name].add_render(
        name: node.value.from,
        node:
      )
    end

    def on_graphql(node)
      @files[node.app_file.name].all_assigns[node.value.to] = node
    end

    def on_background(node)
      return unless node.value.partial_syntax

      @files[node.app_file.name].all_assigns[node.value.to] = node

      return unless node.value.partial_name.is_a?(String)

      @files[node.app_file.name].add_render(
        name: node.value.partial_name,
        node:
      )
    end

    def on_variable_lookup(node)
      @files[node.app_file.name].add_variable_lookup(
        name: node.value.name,
        node:
      )
    end

    def single_file_end_dependencies(app_file)
      @files[app_file.name].all_renders.keys.map do |partial_name|
        next if @files[partial_name]

        partial_file = @platformos_app.partials.detect { |p| p.name == partial_name } # NOTE: undefined partial

        next unless partial_file

        partial_file
      end.compact
    end

    def on_end
      all_global_objects = PlatformosCheck::PlatformosLiquid::Object.labels
      all_global_objects.freeze

      each_template do |(_name, info)|
        if info.app_file.notification?
          # NOTE: `data` comes from graphql for notifications
          check_object(info, all_global_objects + NOTIFICATION_GLOBAL_OBJECTS)
        elsif info.app_file.form?
          # NOTE: `data` comes from graphql for notifications
          check_object(info, all_global_objects + FORM_GLOBAL_OBJECTS)
        else
          check_object(info, all_global_objects)
        end
      end
    end

    private

    attr_reader :config_type

    def each_template
      @files.each do |(name, info)|
        yield [name, info]
      end
    end

    def check_object(info, all_global_objects, render_node = nil, level = 0)
      return if level > 1

      check_undefined(info, all_global_objects, render_node) unless info.app_file.partial? && render_node.nil? # ||

      info.each_partial do |(partial_name, node)|
        next unless @files[partial_name] # NOTE: undefined partial

        partial_info = @files[partial_name]
        partial_variables = node.value.attributes.keys +
                            [node.value.instance_variable_get(:@alias_name)]

        check_object(partial_info, all_global_objects + partial_variables, node, level + 1)
      end
    end

    def check_undefined(info, all_global_objects, render_node)
      all_variables = info.all_variables
      potentially_unused_variables = render_node.value.attributes.keys if render_node
      info.each_variable_lookup(!!render_node) do |(key, node)|
        name, line_number = key

        potentially_unused_variables&.delete(name)

        next if all_variables.include?(name)
        next if all_global_objects.include?(name)

        node = node.parent
        node = node.parent if %i[condition variable_lookup].include?(node.type_name)

        next if node.variable? && node.filters.any? { |(filter_name)| filter_name == "default" }

        if render_node
          add_offense("Missing argument `#{name}`", node: render_node) do |corrector|
            new_attribute = ", #{name}: null"

            start_pos = render_node.end_index
            start_pos -= 1 while start_pos > 0 && render_node.source[start_pos - 1] == ' '
            corrector.insert_after(render_node, new_attribute, start_pos...start_pos)
          end
        elsif !info.app_file.partial?
          add_offense("Undefined object `#{name}`", node:, line_number:)
        end
      end

      potentially_unused_variables -= render_node.value.internal_attributes if render_node && render_node.value.respond_to?(:internal_attributes)
      potentially_unused_variables&.each do |name|
        add_offense("Unused argument `#{name}`", node: render_node) do |corrector|
          match = render_node.markup.match(/(?<attribute>,?\s*#{name}\s*:\s*#{Liquid::QuotedFragment})\s*/)

          corrector.replace(render_node, render_node.markup.sub(match[:attribute], ''), render_node.start_index...render_node.end_index)
        end
      end
    end
  end
end
