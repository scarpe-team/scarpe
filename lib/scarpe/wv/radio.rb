# frozen_string_literal: true

class Scarpe
  class WebviewRadio < Scarpe::WebviewWidget
    attr_reader :text

    def initialize(properties)
      super(properties)
      @checked = properties[:checked]

      bind("click") do
        send_display_event(event_name: "click", target: shoes_linkable_id)
      end
    end

    def element
      HTML.render do |h|
        h.input(type: :radio, id: html_id, onclick: handler_js_code("click"), name: group_name, value: "hmm #{text}", checked: @checked)
      end
    end

    private

    def group_name
      @group || @parent
    end
  end
end
