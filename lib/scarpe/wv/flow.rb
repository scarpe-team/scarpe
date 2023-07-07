# frozen_string_literal: true

class Scarpe
  class WebviewFlow < Scarpe::WebviewSlot
    def initialize(properties)
      super
    end

    protected

    def style
      styles = super

      styles[:display] = "flex"
      styles["flex-direction"] = "row"
      styles["flex-wrap"] = "wrap"

      styles
    end
  end
end
