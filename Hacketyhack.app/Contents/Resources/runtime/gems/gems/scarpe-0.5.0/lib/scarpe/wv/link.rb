# frozen_string_literal: true

module Scarpe::Webview
  class Link < TextDrawable
    def initialize(properties)
      super

      bind("click") do
        send_self_event(event_name: "click")
      end
    end

    def to_calzini_hash
      h = super
      h[:tag] = "a"
      h
    end
  end
end
