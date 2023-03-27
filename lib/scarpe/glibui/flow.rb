# frozen_string_literal: true

class Scarpe
  class GlimmerLibUIFlow < Scarpe::GlimmerLibUIWidget
    include Scarpe::GlimmerLibUIBackground
    include Scarpe::GlimmerLibUIBorder

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
