# frozen_string_literal: true

class Scarpe
  class Flow < Scarpe::Widget
    include Scarpe::Background
    include Scarpe::Border

    def initialize(width: nil, height: nil, margin: nil, padding: nil, &block)
      @width = width
      @height = height
      @margin = margin
      @padding = padding
      instance_eval(&block)
    end

    def element(&block)
      HTML.render do |h|
        h.div(id: html_id, style:, &block)
      end
    end

    private

    def style
      styles = super

      styles[:display] = "flex"
      styles["flex-direction"] = "row"
      styles["flex-wrap"] = "wrap"
      styles[:width] = Dimensions.length(@width) if @width
      styles[:height] = Dimensions.length(@height) if @height

      styles
    end
  end
end
