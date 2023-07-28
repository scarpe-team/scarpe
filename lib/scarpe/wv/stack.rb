# frozen_string_literal: true

class Scarpe
  class WebviewStack < Scarpe::WebviewSlot
    def get_style
      style
    end

    protected

    def style
      {
        display: "flex",
        "flex-direction": "column",
        "align-content": "flex-start",
        "justify-content": "flex-start",
        "align-items": "flex-start",
        overflow: @scroll ? "auto" : nil,
      }.compact.merge(super)
    end
  end
end
