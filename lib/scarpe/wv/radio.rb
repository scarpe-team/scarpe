# frozen_string_literal: true

class Scarpe
  class WebviewRadio < Scarpe::WebviewWidget
    attr_reader :text

    def initialize(properties)
      super

      bind("click") do
        send_self_event(event_name: "click", target: shoes_linkable_id)
      end
    end

    def properties_changed(changes)
      items = changes.delete("checked")
      html_element.toggle_input_button(items)

      super
    end

    def element
      HTML.render do |h|
        h.input(type: :radio, id: html_id, onclick: handler_js_code("click"), name: group_name, value: "hmm #{text}", checked: @checked, style: style)
      end
    end

    private

    def group_name
      @group || @parent
    end
  end
end
