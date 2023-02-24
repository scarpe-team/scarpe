# frozen_string_literal: true

class Scarpe
  class EditLine < Scarpe::Widget
    display_properties :text, :width

    def initialize(text = "", width: nil, &block)
      @block = block
      @text = text

      super

      bind_self_event("change") do |new_text|
        self.text = new_text
        @block&.call(new_text)
      end

      create_display_widget
    end

    def change(&block)
      @block = block
    end
  end

  class WebviewEditLine < WebviewWidget
    attr_reader :text, :width

    def initialize(properties)
      super

      # The JS handler sends a "change" event, which we forward to the Shoes widget tree
      bind("change") do |new_text|
        send_display_event(new_text, event_name: "change", target: shoes_linkable_id)
      end
    end

    def properties_changed(changes)
      t = changes.delete("text")
      if t
        html_element.value = t
      end

      super
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
