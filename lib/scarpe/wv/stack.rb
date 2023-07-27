# frozen_string_literal: true

class Scarpe
  class WebviewStack < Scarpe::WebviewSlot
    def get_style
      style
    end

    protected

    def style
      styles = super

      # styles[:display] = "flex"
      # styles["flex-direction"] = "column"
      # styles["align-content"] = "flex-start"
      # styles["justify-content"] = "flex-start"
      # styles["align-items"] = "flex-start"
      # styles["overflow"] = "auto" if @scroll

      styles
    end

    private

    def options
      @html_attributes.merge(id: html_id, style: style)
    end
  end
end
