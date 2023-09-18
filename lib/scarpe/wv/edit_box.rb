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
      render("edit_box")
    end
  end
end
