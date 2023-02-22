# frozen_string_literal: true

class Scarpe
  class EditBox < Scarpe::Widget
    attr_reader :text, :height, :width

    def initialize(text = nil, height: nil, width: nil, &block)
      @text = text || block.call
      @height = height
      @width = width

      super

      bind_self_event("change") do |new_text|
        @text = new_text
        @callback&.call(new_text)
      end

      display_widget_properties(@text, height:, width:)
    end

    def change(&block)
      @callback = block
    end

    # If this is called from Shoes-side, forward the new value to the display widget
    def text=(text)
      @text = text
      html_element.inner_text = text
      send_display_event(text, event_name: "set_text", target: self.linkable_id)
    end
  end

  class WebviewEditBox < Scarpe::WebviewWidget
    attr_reader :text, :height, :width

    def initialize(text, height:, width:, shoes_linkable_id:)
      @text = text
      @height = height
      @width = width

      super

      # If Shoes sends a change, we change
      bind_shoes_event(event_name: "set_text", target: shoes_linkable_id) do |new_text|
        html_element.inner_text = new_text
      end

      # The JS handler sends a "change" event, which we forward to the Shoes widget tree
      bind("change") do |new_text|
        send_display_event(new_text, event_name: "change", target: shoes_linkable_id)
      end
    end

    def element
      oninput = handler_js_code("change", "this.value")

      HTML.render do |h|
        h.textarea(id: html_id, oninput: oninput, style: style) { text }
      end
    end

    private

    def style
      styles = {}

      styles[:height] = Dimensions.length(height)
      styles[:width] = Dimensions.length(width)

      styles.compact
    end
  end
end
