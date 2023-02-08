# frozen_string_literal: true

class Scarpe
  class Flow < Scarpe::Widget
    def initialize(width: nil, margin: nil, &block)
      @width = width
      @margin = margin
      instance_eval(&block)
    end

    def element(&block)
      HTML.render do |h|
        h.div(id: html_id, style:, &block)
      end
    end

    private

    def style
      styles = {}

      styles[:display] = "flex"
      styles["flex-direction"] = "row"
      styles["flex-wrap"] = "wrap"
      styles[:margin] = Dimensions.length(@margin) if @margin
      styles[:width] = Dimensions.length(@width) if @width

      styles
    end
  end
end
