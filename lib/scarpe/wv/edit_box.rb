# frozen_string_literal: true

module Scarpe::Webview
  class EditBox < Widget
    attr_reader :text, :height, :width

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

      ::Scarpe::Components::HTML.render do |h|
        h.textarea(id: html_id, oninput: oninput, style: style) { text }
      end
    end

    protected

    def style
      super.merge({
        height: Dimensions.length(height),
        width: Dimensions.length(width),
      }.compact)
    end
  end
end
