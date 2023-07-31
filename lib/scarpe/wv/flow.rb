# frozen_string_literal: true

class Scarpe
  class WebviewFlow < Scarpe::WebviewSlot
    def initialize(properties)
      super
    end

    protected

    def style
      {
        display: "flex",
        "flex-direction": "row",
        "flex-wrap": "wrap",
        "align-content": "flex-start",
        "justify-content": "flex-start",
        "align-items": "flex-start",
      }.merge(super)
    end
  end
end
