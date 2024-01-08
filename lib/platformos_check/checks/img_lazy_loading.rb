# frozen_string_literal: true

module PlatformosCheck
  class ImgLazyLoading < HtmlCheck
    severity :suggestion
    categories :html, :performance
    doc docs_url(__FILE__)

    ACCEPTED_LOADING_VALUES = Set.new(%w[lazy eager]).freeze
    LOADING_DEFAULT_ATTRIBUTE = ' loading="eager"'

    def on_img(node)
      loading = node.attributes["loading"]&.downcase
      return if ACCEPTED_LOADING_VALUES.include?(loading)

      add_offense("Use loading=\"eager\" for images visible in the viewport on load and loading=\"lazy\" for others", node:) do |corrector|
        start_pos = node.start_index + node.markup.index('>')
        corrector.insert_after(node, LOADING_DEFAULT_ATTRIBUTE, start_pos...start_pos)
      end
    end
  end
end
