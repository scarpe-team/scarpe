# frozen_string_literal: true

class Scarpe::Webview::SubscriptionItem < Scarpe::Webview::Drawable
  def initialize(properties)
    super

    @stopped = @stopped || false

    bind(@shoes_api_name) do |*args|
      send_self_event(*args, event_name: @shoes_api_name) unless @stopped
    end

    # Watch for the 'stopped' property change from Lacci
    bind("prop_change") do |new_props|
      if new_props.key?("stopped")
        @stopped = !!new_props["stopped"]
      end
    end

    @wrangler = Scarpe::Webview::DisplayService.instance.wrangler

    case @shoes_api_name
    when "animate"
      frame_rate = (@args[0] || 10)
      @counter = 0
      @wrangler.periodic_code("animate_#{@shoes_linkable_id}", 1.0 / frame_rate) do
        unless @stopped
          @counter += 1
          send_self_event(@counter, event_name: @shoes_api_name)
        end
      end
    when "every"
      delay = @args[0]
      @counter = 0
      @wrangler.periodic_code("every_#{@shoes_linkable_id}", delay) do
        unless @stopped
          @counter += 1
          send_self_event(@counter, event_name: @shoes_api_name)
        end
      end
    when "timer"
      delay = @args[0] || 1
      @wrangler.one_shot_code("timer_#{@shoes_linkable_id}", delay) do
        send_self_event(event_name: @shoes_api_name) unless @stopped
      end
    when "motion", "hover", "leave", "click", "release", "keypress", "wheel"
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
      # Those should be set on body, which right now doesn't have a drawable.
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
      new_parent.set_event_callback(self, "onmouseleave", handler_js_code(@shoes_api_name))
    when "click"
      new_parent.set_event_callback(self, "onclick", handler_js_code(@shoes_api_name, "arguments[0].button", "arguments[0].x", "arguments[0].y"))
    when "release"
      new_parent.set_event_callback(self, "onmouseup", handler_js_code(@shoes_api_name, "arguments[0].button", "arguments[0].x", "arguments[0].y"))
    when "keypress"
      # Keypress is a global event in Shoes — it fires on any key press regardless
      # of which element has focus. We bind a document-level keydown handler.
      handler_name = "keypress_#{@shoes_linkable_id}"
      @wrangler.bind(handler_name) do |key_string|
        send_self_event(key_string, event_name: @shoes_api_name)
      end
      # Install a document-level keydown listener that converts JS key events
      # to Shoes-compatible key names. Shoes uses:
      #   - Single characters for regular keys: "a", "b", "1", " "
      #   - Symbols for special keys: :left, :right, :up, :down, etc.
      #   - Strings with modifiers: "alt_a", "control_c", "shift_A"
      @wrangler.instance_variable_get(:@webview).init(<<~JS)
        document.addEventListener('keydown', function(e) {
          var key = e.key;
          var shoesKey;

          // Map JS key names to Shoes key symbols (prefixed with ":")
          var specialKeys = {
            'ArrowLeft': ':left', 'ArrowRight': ':right',
            'ArrowUp': ':up', 'ArrowDown': ':down',
            'Home': ':home', 'End': ':end',
            'PageUp': ':page_up', 'PageDown': ':page_down',
            'Escape': ':escape', 'Backspace': ':backspace',
            'Tab': ':tab', 'Enter': ':return',
            'Delete': ':delete', 'Insert': ':insert',
            'F1': ':f1', 'F2': ':f2', 'F3': ':f3', 'F4': ':f4',
            'F5': ':f5', 'F6': ':f6', 'F7': ':f7', 'F8': ':f8',
            'F9': ':f9', 'F10': ':f10', 'F11': ':f11', 'F12': ':f12',
            ' ': ' ', 'Control': null, 'Shift': null, 'Alt': null, 'Meta': null
          };

          if (specialKeys.hasOwnProperty(key)) {
            shoesKey = specialKeys[key];
            if (shoesKey === null) return; // Ignore bare modifier keys
          } else if (key.length === 1) {
            // Regular character key
            shoesKey = key;
          } else {
            // Unknown special key, pass through as lowercase symbol
            shoesKey = ':' + key.toLowerCase();
          }

          // Add modifier prefixes (Shoes convention: "alt_a", "control_c", etc.)
          if (shoesKey && !shoesKey.startsWith(':')) {
            var prefix = '';
            if (e.altKey) prefix += 'alt_';
            if (e.ctrlKey) prefix += 'control_';
            // Shift is implicit in the character for regular keys
            shoesKey = prefix + shoesKey;
          } else if (shoesKey && shoesKey.startsWith(':')) {
            var prefix = '';
            if (e.altKey) prefix += 'alt_';
            if (e.ctrlKey) prefix += 'control_';
            if (e.shiftKey) prefix += 'shift_';
            if (prefix) shoesKey = prefix + shoesKey.substring(1);
          }

          if (shoesKey) #{handler_name}(shoesKey);
        });
      JS
    when "wheel"
      # Wheel event (mouse wheel / trackpad scroll). Positive delta = scroll up/away from user.
      # In browsers, deltaY is positive when scrolling down (content moves up), which is
      # opposite to what Shoes3 expects. We negate it for Shoes compatibility.
      new_parent.set_event_callback(
        self,
        "onwheel",
        handler_js_code(
          @shoes_api_name,
          "-arguments[0].deltaY",  # Negate for Shoes3 convention: positive = up
          "arguments[0].clientX",
          "arguments[0].clientY",
        ),
      )
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
