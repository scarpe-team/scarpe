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

    def get_style
      style
    end

    private

    def style
      styles = super

      styles["margin-top"] = @margin_top
      styles["margin-bottom"] = @margin_bottom
      styles["margin-left"] = @margin_left
      styles["margin-right"] = @margin_right

      styles[:display] = "flex"
      styles["flex-direction"] = "column"
      styles[:width] = Dimensions.length(@width) if @width
      styles[:height] = Dimensions.length(@height) if @height
      styles["overflow"] = "auto" if @scroll

      styles
    end
  end
end
