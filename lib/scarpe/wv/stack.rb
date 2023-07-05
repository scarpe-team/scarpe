# frozen_string_literal: true

class Scarpe
  class WebviewStack < Scarpe::WebviewSlot
    def get_style
      style
    end

    protected

    def style
      styles = super

      styles[:display] = "flex"
      styles["flex-direction"] = "column"
      styles["overflow"] = "auto" if @scroll

      styles
    end
  end
end
