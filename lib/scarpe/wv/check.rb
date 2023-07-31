# frozen_string_literal: true

class Scarpe
  class WebviewCheck < Scarpe::WebviewWidget
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
      HTML.render do |h|
        h.input(type: :checkbox, id: html_id, onclick: handler_js_code("click"), value: "hmm #{text}", checked: @checked, style:)
      end
    end
  end
end
