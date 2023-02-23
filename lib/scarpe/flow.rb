# frozen_string_literal: true

class Scarpe
  class Flow < Scarpe::Widget
    include Scarpe::Background
    include Scarpe::Border

    display_properties :width, :height, :margin, :padding

    def initialize(width: nil, height: nil, margin: nil, padding: nil, &block)
      super

      # Create the display-side widget *before* instance_eval, which will add child widgets with their display widgets
      create_display_widget

      instance_eval(&block)
    end
  end

  class WebviewFlow < Scarpe::WebviewWidget
    include Scarpe::Background
    include Scarpe::Border

    def initialize(properties)
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
      styles[:width] = Dimensions.length(@width) if @width
      styles[:height] = Dimensions.length(@height) if @height

      styles
    end
  end
end
