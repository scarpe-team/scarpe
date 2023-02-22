# frozen_string_literal: true

class Scarpe
  class EditLine < Scarpe::Widget
    attr_reader :text

    def initialize(text = "", width: nil, &block)
      @block = block
      @text = text
      @width = width

      super

      bind_self_event("change") do |new_text|
        @text = new_text
        @block&.call(new_text)
      end

      display_widget_properties(text, width:)
    end

    def change(&block)
      @block = block
    end

    def text=(new_text)
      @text = new_text

      send_display_event(text, event_name: "set_text", target: self.linkable_id)
    end
  end

  class WebviewEditLine < WebviewWidget
    attr_reader :text, :width

    def initialize(text, width:, shoes_linkable_id:)
      @text = text
      @width = width

      super

      # If Shoes sends a change, we change
      bind_shoes_event(event_name: "set_text", target: shoes_linkable_id) do |new_text|
        html_element.value = new_text
      end

      # The JS handler sends a "change" event, which we forward to the Shoes widget tree
      bind("change") do |new_text|
        send_display_event(new_text, event_name: "change", target: shoes_linkable_id)
      end
    end

    def element
      oninput = handler_js_code("change", "this.value")

      HTML.render do |h|
        h.input(id: html_id, oninput: oninput, value: @text, style: style)
      end
    end

    private

    def style
      styles = {}

      styles[:width] = Dimensions.length(@width) if @width

      styles
    end
  end
end
