# frozen_string_literal: true

module Scarpe::Webview
  class ListBox < Widget
    attr_reader :selected_item, :items, :height, :width

    def initialize(properties)
      super(properties)

      # The JS handler sends a "change" event, which we forward to the Shoes widget tree
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
