# frozen_string_literal: true

class Scarpe
  class WebviewStack < Scarpe::WebviewWidget
    include Scarpe::WebviewBackground
    include Scarpe::WebviewBorder
    include Scarpe::WebviewSpacing

    def initialize(properties)
      super
    end

    def element(&block)
      HTML.render do |h|
        h.div(id: html_id, style: style, &block)
      end
    end

    private

    def style
      styles = super

      styles[:display] = "flex"
      styles["flex-direction"] = "column"
      styles[:width] = Dimensions.length(@width) if @width
      styles[:height] = Dimensions.length(@height) if @height
      styles["overflow"] = "auto" if @scroll

      styles
    end
  end
end
