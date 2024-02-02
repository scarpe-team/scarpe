# frozen_string_literal: true

module Scarpe::Webview
  class EditBox < Drawable
    attr_reader :text, :height, :width, :tooltip , :font

    def initialize(properties)
      super

      # The JS handler sends a "change" event, which we forward to the Shoes drawable tree
      bind("change") do |new_text|
        send_self_event(new_text, event_name: "change")
      end
      bind("hover") do
        send_self_event(event_name: "hover")
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
      render("edit_box")
    end
  end
end
