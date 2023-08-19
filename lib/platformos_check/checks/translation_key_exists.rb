# frozen_string_literal: true

module PlatformosCheck
  class TranslationKeyExists < LiquidCheck
    severity :error
    category :translation
    doc docs_url(__FILE__)

    def initialize
      @schema_locales = {}
      @nodes = {}
    end

    def on_document(node)
      @nodes[node.platformos_app_file.name] = []
    end

    def on_variable(node)
      return unless @platformos_app.default_locale_json&.content.is_a?(Hash)
      return unless node.filters.any? { |name, _| %w[t translate].include?(name) }

      @nodes[node.platformos_app_file.name] << node
    end

    def on_schema(node)
      return unless (schema_locales = node.inner_json&.dig("locales", @platformos_app.default_locale))

      @schema_locales = schema_locales
    end

    def on_end
      @nodes.each_pair do |_file_name, file_nodes|
        file_nodes.each do |node|
          next unless (key_node = node.children.first)
          next unless key_node.value.is_a?(String)
          next if key_exists?(key_node.value, @platformos_app.default_locale_json.content) || key_exists?(key_node.value, @schema_locales) || ShopifyLiquid::SystemTranslations.include?(key_node.value)

          add_offense(
            @schema_locales.empty? ? "'#{key_node.value}' does not have a matching entry in '#{@platformos_app.default_locale_json.relative_path}'" : "'#{key_node.value}' does not have a matching entry in '#{@platformos_app.default_locale_json.relative_path}' or '#{node.platformos_app_file.relative_path}'",
            node:,
            markup: key_node.value
          ) do |corrector|
            corrector.add_translation(@platformos_app.default_locale_json, key_node.value.split("."), "TODO")
          end
        end
      end
    end

    private

    def key_exists?(key, pointer)
      key.split(".").each do |token|
        return false unless pointer.is_a?(Hash)
        return false unless pointer.key?(token)

        pointer = pointer[token]
      end

      true
    end
  end
end
