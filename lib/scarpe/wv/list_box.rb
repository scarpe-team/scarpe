# frozen_string_literal: true

module Scarpe::Webview
  class ListBox < Drawable
    attr_reader :selected_item, :items, :height, :width, :choose

    def initialize(properties)
      super(properties)

      bind("change") do |new_item|
        send_self_event(new_item, event_name: "change")
      end
    end

    def properties_changed(changes)
      selected = changes.delete("selected_item")
      if selected
        html_element.value = selected
      end
      super
    end

    def element
      render("list_box")
    end
  end
end
