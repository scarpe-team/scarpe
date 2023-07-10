# frozen_string_literal: true

class Scarpe
  class WebviewSlot < Scarpe::WebviewWidget
    include Scarpe::WebviewBackground
    include Scarpe::WebviewBorder
    include Scarpe::WebviewSpacing

    def initialize(properties)
      @event_callbacks = {}

      super
    end

    def element(&block)
      HTML.render do |h|
        h.div(attributes.merge(id: html_id, style: style), &block)
      end
    end

    def set_event_callback(obj, event_name, js_code)
      event_name = event_name.to_s
      @event_callbacks[event_name] ||= {}
      if @event_callbacks[event_name][obj]
        raise "Can't have two callbacks on the same event, from the same object, on the same parent!"
      end

      @event_callbacks[event_name][obj] = js_code

      update_dom_event(event_name)
    end

    def remove_event_callback(obj, event_name)
      event_name = event_name.to_s
      @event_callbacks[event_name] ||= {}
      @event_callbacks[event_name].delete(obj)

      update_dom_event(event_name)
    end

    def remove_event_callbacks(obj)
      changed = []

      @event_callbacks.each do |event_name, items|
        changed << event_name if items.delete(obj)
      end

      changed.each { |event_name| update_dom_event(event_name) }
    end

    protected

    def update_dom_event(event_name)
      html_element.set_attribute(event_name, @event_callbacks[event_name].values.join(";"))
    end

    def attributes
      attr = {}

      @event_callbacks.each do |event_name, handlers|
        attr[event_name] = handlers.values.join(";")
      end

      attr
    end

    def style
      styles = super

      styles["margin-top"] = @margin_top if @margin_top
      styles["margin-bottom"] = @margin_bottom if @margin_bottom
      styles["margin-left"] = @margin_left if @margin_left
      styles["margin-right"] = @margin_right if @margin_right

      styles[:width] = Dimensions.length(@width) if @width
      styles[:height] = Dimensions.length(@height) if @height

      styles
    end
  end
end
