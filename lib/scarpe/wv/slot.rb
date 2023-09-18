# frozen_string_literal: true

module Scarpe::Webview
  class Slot < Widget
    def initialize(properties)
      @event_callbacks = {}

      super
    end

    def element(&block)
      props = display_properties.merge("html_attributes" => html_attributes)
      render_name = self.class.name.split("::")[-1].downcase # usually "stack" or "flow" or "documentroot"
      render(render_name, props, &block)
    end

    def set_event_callback(obj, event_name, js_code)
      event_name = event_name.to_s
      @event_callbacks[event_name] ||= {}
      if @event_callbacks[event_name][obj]
        raise Scarpe::DuplicateCallbackError, "Can't have two callbacks on the same event, from the same object, on the same parent!"
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

    # These get added for event handlers and passed to Calzini
    def html_attributes
      attr = {}

      @event_callbacks.each do |event_name, handlers|
        attr[event_name] = handlers.values.join(";")
      end

      attr
    end
  end
end
