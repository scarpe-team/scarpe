# frozen_string_literal: true

class Scarpe
  class Stack < Scarpe::Widget
    include Scarpe::Background
    include Scarpe::Border

    def initialize(width: nil, height: nil, top: nil, left: nil, margin: nil, &block)
      @width = width
      @height = height
      @top = top
      @left = left
      @margin = margin
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

      styles[:position] = positioning? ? "absolute" : "relative"

      styles[:width] = Dimensions.length(@width) if @width
      styles[:height] = Dimensions.length(@height) if @height

      styles[:top] = Dimensions.length(@top) if @top
      styles[:left] = Dimensions.length(@left) if @left

      styles[:margin] = Dimensions.length(@margin) if @margin

      styles
    end

    def positioning?
      @top || @left
    end
  end
end
