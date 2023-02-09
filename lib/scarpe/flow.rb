# frozen_string_literal: true

class Scarpe
  class Flow < Scarpe::Widget
    include Scarpe::Background
    include Scarpe::Border

    def initialize(width: nil, height: nil, margin: nil, margin_left: nil, margin_top: nil, &block)
      @width = width
      @height = height
      @margin = margin
      @margin_left = margin_left
      @margin_top = margin_top
      instance_eval(&block)
      super
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
      styles[:margin] = Dimensions.length(@margin) if @margin
      styles["margin-left"] = Dimensions.length(@margin_left) if @margin_left
      styles["margin-top"] = Dimensions.length(@margin_top) if @margin_top
      styles[:width] = Dimensions.length(@width) if @width
      styles[:height] = Dimensions.length(@height) if @height

      styles
    end
  end
end
