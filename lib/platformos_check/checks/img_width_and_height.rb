# frozen_string_literal: true

module PlatformosCheck
  # Reports errors when trying to use parser-blocking script tags
  class ImgWidthAndHeight < HtmlCheck
    severity :error
    categories :html, :performance
    doc docs_url(__FILE__)

    ENDS_IN_CSS_UNIT = /(cm|mm|in|px|pt|pc|em|ex|ch|rem|vw|vh|vmin|vmax|%)$/i

    def on_img(node)
      width = node.attributes["width"]
      height = node.attributes["height"]

      record_units_in_field_offenses("width", width, node:)
      record_units_in_field_offenses("height", height, node:)

      return if node.attributes["src"].nil? || (width && height)

      missing_width = width.nil?
      missing_height = height.nil?
      error_message = if missing_width && missing_height
                        "Missing width and height attributes"
                      elsif missing_width
                        "Missing width attribute"
                      elsif missing_height
                        "Missing height attribute"
                      end

      add_offense(error_message, node:)
    end

    private

    def record_units_in_field_offenses(attribute, value, node:)
      return unless ENDS_IN_CSS_UNIT.match?(value)

      value_without_units = value.gsub(ENDS_IN_CSS_UNIT, '')
      add_offense(
        "The #{attribute} attribute does not take units. Replace with \"#{value_without_units}\"",
        node:
      )
    end
  end
end
