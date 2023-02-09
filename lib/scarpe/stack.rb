class Scarpe
  class Stack < Scarpe::Widget
    include Scarpe::Background
    include Scarpe::Border

    def initialize(width: nil, height: nil, margin: nil, &block)
      @width = width
      @height = height
      @margin = margin
      instance_eval(&block)
    end

    def element
      HTML.render do |h|
        h.div(id: html_id, style: style) { yield }
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

      styles
    end
  end
end
