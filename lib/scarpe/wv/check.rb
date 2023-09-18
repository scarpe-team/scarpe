# frozen_string_literal: true

module Scarpe::Webview
  class Check < Widget
    attr_reader :text

    def initialize(properties)
      super

      bind("click") do
        send_self_event(event_name: "click", target: shoes_linkable_id)
      end
    end

    def properties_changed(changes)
      checked = changes.delete("checked")

      html_element.toggle_input_button(checked)

      super
    end

    def element
      render("check")
    end
  end
end
