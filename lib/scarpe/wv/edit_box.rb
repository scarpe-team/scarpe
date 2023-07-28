# frozen_string_literal: true

class Scarpe
  class WebviewEditBox < Scarpe::WebviewWidget
    attr_reader :text, :height, :width, :margin_bottom

    def initialize(properties)
      super

      # The JS handler sends a "change" event, which we forward to the Shoes widget tree
      bind("change") do |new_text|
        send_self_event(new_text, event_name: "change")
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
        h.textarea(id: html_id, oninput: oninput, style: style) { text }
      end
    end

    private

    def style
      styles = {}

      styles[:height] = Dimensions.length(height)
      styles[:width] = Dimensions.length(width)
      styles["margin-bottom"] = margin_bottom

      styles.compact
    end
  end
end
