# frozen_string_literal: true

module Scarpe::Webview
  class Alert < Widget
    def initialize(properties)
      super

      bind("click") do
        send_self_event(event_name: "click")
      end
    end

    def element
      render("alert")
    end
  end
end
