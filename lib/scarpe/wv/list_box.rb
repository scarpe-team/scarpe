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
      onchange = handler_js_code("change", "this.options[this.selectedIndex].value")

      select_attrs = { id: html_id, onchange: onchange, style: style }
      option_attrs = { value: nil, selected: false }

      Scarpe::Components::HTML.render do |h|
        h.select(**select_attrs) do
          items.each do |item|
            h.option(**option_attrs, value: item, selected: (item == selected_item)) { item }
          end
        end
      end
    end

    protected

    def style
      styles = super

      styles[:height] = Dimensions.length(height) if height
      styles[:width] = Dimensions.length(width) if width

      styles
    end
  end
end
