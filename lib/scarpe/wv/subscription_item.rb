# frozen_string_literal: true

class Scarpe::WebviewSubscriptionItem < Scarpe::WebviewWidget
  def initialize(properties)
    super

    bind(@shoes_api_name) do |*args|
      send_self_event(*args, event_name: @shoes_api_name)
    end
  end

  def element
    ""
  end

  # This will get called once we know the parent, which is useful for events
  # like hover, where our subscription is likely to depend on what our parent is.
  def set_parent(new_parent)
    super

    case @shoes_api_name
    when "motion"
      # TODO: what do we do for whole-screen mousemove outside the window?
      # Those should be set on body, which right now doesn't have a widget.
      # TODO: figure out how to handle alt and meta keys - does Shoes3 recognise those?
      new_parent.set_event_callback(
        self,
        "onmousemove",
        handler_js_code(
          @shoes_api_name,
          "arguments[0].x",
          "arguments[0].y",
          "arguments[0].ctrlKey",
          "arguments[0].shiftKey",
        ),
      )
    when "hover"
      new_parent.set_event_callback(self, "onmouseenter", handler_js_code(@shoes_api_name))
    when "click"
      new_parent.set_event_callback(self, "onclick", handler_js_code(@shoes_api_name, "arguments[0].button", "arguments[0].x", "arguments[0].y"))
    else
      raise "Unknown Shoes event API: #{@shoes_api_name}!"
    end
  end

  def destroy_self
    @parent.remove_event_callbacks(self)
    super
  end
end
