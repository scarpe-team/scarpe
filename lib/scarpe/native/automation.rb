# frozen_string_literal: true

require "fileutils"

module Scarpe::Native
  class AutomationError < Scarpe::Error; end

  # A drawable's box in window coordinates (logical pixels).
  Rect = Struct.new(:x, :y, :w, :h) do
    def center
      [x + w / 2.0, y + h / 2.0]
    end
  end

  # Look-and-click requests (DESIGN 4.1 req ops) shared by Shoes-Spec and `scarpe peek`.
  # Each request dispatches the events it caused before returning, so Ruby handlers have run
  # by the time a test checks the result. A request about one drawable goes to its window.
  class Automation
    REQUEST_TIMEOUT = 30.0
    OUTSIDE = -1

    # The window every request goes to (peek --window). Unset, the first open app answers
    # the looking and Rust's active window takes the typing.
    attr_accessor :app

    def initialize(service)
      @service = service
    end

    def self.snapshot_path(name)
      name = name.to_s
      name += ".png" if File.extname(name).empty?
      return name if name.start_with?("/")

      File.join(ENV["SCARPE_NATIVE_SNAPSHOT_DIR"] || File.join(ROOT, "spec", "results", "snapshots"), name)
    end

    def click(target, button: 1)
      request(:click, target: target, button: button, app: app_for(target))
    end

    def mouse(action, x, y, button: 1, app: @app)
      request(:mouse, action: action.to_s, x: x, y: y, button: button, app: app)
    end

    # Hover events fire on transitions, so the pointer leaves first and then arrives.
    def hover(id)
      x, y = rect_of!(id).center
      mouse(:move, OUTSIDE, OUTSIDE, app: app_of(id))
      mouse(:move, x, y, app: app_of(id))
    end

    def leave(id)
      x, y = rect_of!(id).center
      mouse(:move, x, y, app: app_of(id))
      mouse(:move, OUTSIDE, OUTSIDE, app: app_of(id))
    end

    def type(text)
      request(:type, text: text.to_s, app: @app)
    end

    def key(name)
      request(:key, key: name.to_s, app: @app)
    end

    # dy in logical pixels, positive scrolls down; at (x, y), or where the pointer is.
    def wheel(dy, x: nil, y: nil)
      request(:wheel, dy: dy, x: x, y: y, app: @app)
    end

    def layout(app: app_id)
      Array(request(:layout, app: app)).map { |node| node.transform_keys(&:to_sym) }
    end

    def rect_of(id)
      node = layout(app: app_of(id)).find { |entry| entry[:id] == id }
      node && Rect.new(node[:x], node[:y], node[:w], node[:h])
    end

    def rect_of!(id)
      rect_of(id) || raise(AutomationError, "Drawable #{id} is not laid out (hidden, destroyed or never shown)")
    end

    def snapshot(path, scale: nil)
      FileUtils.mkdir_p(File.dirname(path))
      request(:snapshot, path: path, app: app_id, scale: scale)
    end

    def pixel(x, y)
      request(:pixel, x: x, y: y, app: app_id)
    end

    def focused
      request(:focused)
    end

    # The accessibility tree as a screen reader meets it (DESIGN 12): the window's Hash, with
    # Symbol keys, each node's :children inside it. platform: what AppKit hands VoiceOver,
    # read from a real window (macOS).
    def a11y(app: app_id, platform: false)
      symbolize(request(:a11y, app: app, platform: platform))
    end

    # What a screen reader asks of one node: :click, :focus, :set_value (with a value), :expand
    # or :collapse. Rust finds the node's own window.
    def a11y_action(id, action, value: nil)
      request(:a11y_action, id: id, action: action.to_s, value: value&.to_s, app: @app)
    end

    # The same through AppKit, the way VoiceOver works a real window: on the element with this title.
    def platform_a11y_action(title, action, value: nil)
      request(:a11y_action, platform: true, name: title.to_s, action: action.to_s, value: value&.to_s, app: app_id)
    end

    def resize(width, height)
      request(:resize, app: app_id, w: width, h: height)
    end

    def frames(count = 1)
      request(:frames, n: count)
    end

    # Pumps queued events and changes through, beats the heart as the pump does (so a slot made
    # since starts, ledger H8), then waits until Rust has painted all of it.
    def wait_frames(count = 1)
      dispatch_caused_events
      @service.surfacing_handler_errors { Shoes::DisplayService.dispatch_event("heartbeat", nil) }
      dispatch_caused_events
      frames(count)
    end

    # Under a frozen clock (Shoes-Spec), jumps from one timer deadline to the next so exactly the
    # timers due in the span fire, in order. Otherwise runs the real loop for that long.
    def advance(seconds)
      clock = @service.clock
      if clock.frozen?
        target = clock.now + seconds
        while (due = @service.timers.next_due_at) && due <= target + Timers::EPSILON
          clock.travel_to(due)
          @service.surfacing_handler_errors { @service.fire_timers }
          dispatch_caused_events
        end
        clock.travel_to(target)
      else
        deadline = clock.now + seconds
        @service.pump.step while clock.now < deadline && @service.any_app_open?
      end
      wait_frames
    end

    private

    def app_id
      @app || @service.current_app_id
    end

    def app_of(id)
      @service.app_id_of(id) || app_id
    end

    def app_for(target)
      id = target.is_a?(Hash) ? (target[:id] || target["id"]) : nil
      id ? app_of(id) : app_id
    end

    def symbolize(value)
      case value
      when Hash then value.to_h { |key, v| [key.to_sym, symbolize(v)] }
      when Array then value.map { |v| symbolize(v) }
      else value
      end
    end

    # Handlers run now, and one that raises fails the caller (a test, a peek step).
    def dispatch_caused_events
      @service.surfacing_handler_errors { @service.pump.drain }
      @service.child.flush
    end

    def request(op, **fields)
      reply = @service.child.request(op, timeout: REQUEST_TIMEOUT, **fields)
      dispatch_caused_events
      if reply["error"]
        detail = reply["value"].nil? ? "" : " (#{reply["value"].inspect})"
        raise AutomationError, "#{op} failed: #{reply["error"]}#{detail}"
      end
      reply["value"]
    end
  end
end
