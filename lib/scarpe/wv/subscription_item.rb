# frozen_string_literal: true

class Scarpe::Webview::SubscriptionItem < Scarpe::Webview::Widget

  def initialize(properties)
    super

    bind(@shoes_api_name) do |*args|
      send_self_event(*args, event_name: @shoes_api_name)
    end

    @wrangler = Scarpe::Webview::DisplayService.instance.wrangler

    case @shoes_api_name
    when "animate"
      frame_rate = (@args[0] || 10)
      @counter = 0
      @wrangler.periodic_code("animate_#{@shoes_linkable_id}", 1.0 / frame_rate) do
        @counter += 1
        send_self_event(@counter, event_name: @shoes_api_name)
      end
    when "every"
      delay = @args[0]
      @counter = 0
      @wrangler.periodic_code("every_#{@shoes_linkable_id}", delay) do
        @counter += 1
        send_self_event(@counter, event_name: @shoes_api_name)
      end
    when "timer"
      # JS setTimeout?
      raise "Implement me!"
    when "motion", "hover", "leave", "click", "release", "keypress"
      # Wait for set_parent
    else
      raise Scarpe::UnknownShoesEventAPIError, "Unknown Shoes event API: #{@shoes_api_name}!"
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
    when "leave"
      raise "Implement me!"
    when "click"
      new_parent.set_event_callback(self, "onclick", handler_js_code(@shoes_api_name, "arguments[0].button", "arguments[0].x", "arguments[0].y"))
    when "release"
      raise "Implement me!"
    when "keypress"
      raise "Implement me!"
    when "animate", "every", "timer"
      # These were handled in initialize(), ignore them here
    else
      raise Scarpe::UnknownShoesEventAPIError, "Unknown Shoes event API: #{@shoes_api_name}!"
    end
  end

  def destroy_self
    @parent&.remove_event_callbacks(self)
    super
  end
end
