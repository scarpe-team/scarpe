# frozen_string_literal: true

class Scarpe
  class GlimmerLibUIStack < Scarpe::GlimmerLibUIWidget
    include Scarpe::GlimmerLibUIBackground
    include Scarpe::GlimmerLibUIBorder
    include Scarpe::GlimmerLibUISpacing

    def initialize(properties)
      super
    end

    def display(properties = {})
      <<~GTEXT
        vertical_box {
          #{@children.map(&:display).join}
        }.show
      GTEXT
    end
    # Marker from webview
    # def style
    #   styles = super

    #   styles[:display] = "flex"
    #   styles["flex-direction"] = "column"
    #   styles[:width] = Dimensions.length(@width) if @width
    #   styles[:height] = Dimensions.length(@height) if @height
    #   styles["overflow"] = "auto" if @scroll

    #   styles
    # end
  end
end
