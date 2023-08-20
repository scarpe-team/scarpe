# frozen_string_literal: true

module Scarpe::Webview
  class Flow < Slot
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
