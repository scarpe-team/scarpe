# frozen_string_literal: true

class Scarpe
  class Stack < Scarpe::Widget
    include Scarpe::Background
    include Scarpe::Border
    include Scarpe::Spacing

    def initialize(width: nil, height: nil, margin: nil, padding: nil, scroll: false, **options, &block)
      @width = width
      @height = height
      @margin = margin
      @padding = padding
      @scroll = scroll
      @options = options

      super

      # Create the display-side widget *before* instance_eval, which will add child widgets with their display widgets
      display_widget_properties(width:, height:, margin:, padding:, scroll:, options:)

      instance_eval(&block)
    end
  end

  class WebviewStack < Scarpe::WebviewWidget
    include Scarpe::Background
    include Scarpe::Border
    include Scarpe::Spacing

    def initialize(width:, height:, margin:, padding:, scroll:, options:, shoes_linkable_id:)
      @width = width
      @height = height
      @margin = margin
      @padding = padding
      @scroll = scroll
      @options = options

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
