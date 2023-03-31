# frozen_string_literal: true

class Scarpe
  class GlimmerLibUIFlow < Scarpe::GlimmerLibUIWidget
    include Scarpe::GlimmerLibUIBackground
    include Scarpe::GlimmerLibUIBorder

    def initialize(properties)
      super
    end

    def display(properties = {})
      <<~GTEXT
        horizontal_box {
          #{@children.map(&:display).join}
        }.show
      GTEXT
    end

    # Marker from webview
    # def style
    #   styles = super

    #   styles[:display] = "flex"
    #   styles["flex-direction"] = "row"
    #   styles["flex-wrap"] = "wrap"
    #   styles[:width] = Dimensions.length(@width) if @width
    #   styles[:height] = Dimensions.length(@height) if @height

    #   styles
    # end
  end
end
