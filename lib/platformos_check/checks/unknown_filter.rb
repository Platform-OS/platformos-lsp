# frozen_string_literal: true

module PlatformosCheck
  #
  # Unwanted:
  #
  # {{ x | some_unknown_filter }}
  #
  # Wanted:
  #
  # {{ x | upcase }}
  #
  class UnknownFilter < LiquidCheck
    severity :error
    category :liquid
    doc docs_url(__FILE__)

    def on_variable(node)
      used_filters = node.filters.map { |name, *_rest| name }
      undefined_filters = used_filters - PlatformosLiquid::Filter.labels - PlatformosLiquid::Filter.aliases

      undefined_filters.each do |undefined_filter|
        add_offense("Undefined filter `#{undefined_filter}`", node:)
      end
    end
  end
end
