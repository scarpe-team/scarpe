# frozen_string_literal: true

class Scarpe
  class Stack < Scarpe::Widget
    include Scarpe::Background
    include Scarpe::Border

    def initialize(width: nil, height: nil, margin: nil, scroll: false, &block)
      @width = width
      @height = height
      @margin = margin
      @scroll = scroll
      instance_eval(&block)
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
      styles[:margin] = Dimensions.length(@margin) if @margin
      styles[:width] = Dimensions.length(@width) if @width
      styles[:height] = Dimensions.length(@height) if @height
      styles["overflow"] = "auto" if @scroll

      styles
    end
  end
end
