# frozen_string_literal: true

# Lacci keeps the rects the display pushes back (cross-lane contract a) in a class-level Hash,
# as it keeps para_hit_cache. A Lacci without that accessor gets this one.
unless Shoes::DisplayService.respond_to?(:layout_cache)
  class << Shoes::DisplayService
    def layout_cache
      @layout_cache ||= {}
    end
  end
end

module Scarpe::Native
  # Runs block on the first heartbeat, which the pump sends once apps are running.
  def self.on_first_heartbeat(&block)
    fired = false
    Shoes::DisplayService.subscribe_to_event("heartbeat", nil) do |*_args, **_kwargs|
      next if fired

      fired = true
      block.call
    end
  end

  def self.truthy_env?(name)
    value = ENV[name].to_s.downcase
    !value.empty? && !%w[0 false no].include?(value)
  end

  # Lacci's display service for the native backend. Turns Lacci's bus events into protocol
  # messages for the Rust child (DESIGN 4.1) and the child's messages back into bus events
  # and side-channel writes (DESIGN 4.2).
  class DisplayService < Shoes::DisplayService
    include Shoes::Log

    LIBRARY_DIRS = %w[lacci lib scarpe-components].map { |dir| File.join(ROOT, dir) + "/" }.freeze

    class << self
      attr_accessor :instance
    end

    attr_reader :clock, :timers, :builtins, :automation, :pump

    def initialize
      super()
      self.class.instance = self
      log_init("Scarpe::Native::DisplayService")

      @headless = Scarpe::Native.truthy_env?("SCARPE_NATIVE_HEADLESS")
      @ghost = Scarpe::Native.truthy_env?("SCARPE_NATIVE_GHOST")
      @clock = Clock.new
      @timers = Timers.new
      @builtins = Builtins.new(self, interactive: !@headless && !@ghost)
      @automation = Automation.new(self)
      @pump = Pump.new(self)
      @open_apps = {} # every app that has run => whether its window is still open
      @child_log = Shoes::Log.logger("scarpe-native")

      on_bus("run", nil) { run_latest_app }
      on_bus("destroy", nil) { quit_all }
      listen_to_drawables
    end

    def child
      @child ||= start_child
    end

    # Lacci -> Rust

    def create_display_drawable_for(kind, id, properties, parent_id:, is_widget:)
      # At birth an unset style and an absent one mean the same, so nils stay home.
      props = Normalize.props(kind, properties).compact
      index = index_in_parent(id)
      display = DisplayDrawable.new(id, kind, app_id_for(kind, id, parent_id), props)
      display.attach_to(display_drawable(parent_id), index)
      set_drawable_pairing(id, display)

      message = { t: "create", id: id, kind: kind, parent: parent_id, index: index, widget: is_widget, props: props }
      if kind == "App"
        message[:doc_root] = id + 1
        message[:owner] = Normalize.value(properties["owner"])
      end
      child.post(message)

      if kind == "SubscriptionItem"
        timers.add(id, properties["shoes_api_name"].to_s, properties["args"],
          now: clock.now, app_id: display.app_id, stopped: properties["stopped"])
      end
      display
    end

    def builtin(cmd_name, args)
      value = nil
      value = @builtins.answer(cmd_name, args)
    ensure
      Shoes::DisplayService.set_builtin_response(value)
    end

    def register_font(font)
      path = Normalize.font_path(font)
      child.post(t: "font", path: path) if path
    end

    # Rust -> Lacci

    def receive(message)
      case message["t"]
      when "event" then dispatch_from_child(message["name"], message["target"], message["args"] || [])
      when "mouse" then Shoes::DisplayService.mouse_state = message["state"]
      when "para_hit" then Shoes::DisplayService.para_hit_cache[message["id"]] = message["value"]
      when "layout" then laid_out(message["rects"])
      when "resize" then resized(message["app"], message["w"], message["h"])
      when "scroll" then lacci_drawable(message["id"])&.instance_variable_set(:@scroll_top, message["top"])
      when "closed" then closed(message["app"])
      when "log" then log_from_child(message["level"].to_s, message["msg"])
      else @log.warn("Unknown message from scarpe-native: #{message.inspect[0, 200]}")
      end
    end

    # A handler that raises is logged and forgotten, so one bad block never takes the window down.
    # Inside surfacing_handler_errors (test code clicking things) it is kept to raise afterwards.
    def dispatch_from_child(name, target, args)
      Shoes::DisplayService.dispatch_event(name, target, *decode_args(name, target, args))
    rescue StandardError => e
      drop_unstarted_apps
      @surfaced_errors ? @surfaced_errors << e : report_handler_error(e, "#{name} handler for #{target.inspect}")
    end

    # Test code wants to see what its clicks broke, as an error in the test, not a log line.
    def surfacing_handler_errors
      outer = @surfaced_errors
      @surfaced_errors = []
      result = yield
      raise @surfaced_errors.first unless @surfaced_errors.empty?

      result
    ensure
      @surfaced_errors = outer
    end

    def fire_timers
      timers.fire_due(clock.now) { |event, id, args| dispatch_from_child(event, id, args) }
    end

    def dispatch_heartbeat
      Shoes::DisplayService.dispatch_event("heartbeat", nil)
    rescue StandardError => e
      drop_unstarted_apps
      report_handler_error(e, "heartbeat handler")
    end

    # Lifecycle

    def any_app_open?
      @open_apps.value?(true)
    end

    def current_app_id
      @open_apps.key(true)
    end

    # The app a drawable belongs to, so automation aimed at it reaches its window.
    def app_id_of(id)
      display_drawable(id)&.app_id
    end

    # Shoes-Spec runs: nobody can click a dialog, and time only moves when the test says so.
    def spec_mode!
      @builtins.interactive = false
      @clock.freeze!
    end

    def destroy
      quit_all
    end

    def shutdown
      return unless @child

      @child.post(t: "quit", app: nil)
      @child.flush
      @child.close
    end

    private

    def start_child
      started = Child.start(headless: @headless, ghost: @ghost)
      at_exit { started.close }
      started
    end

    def on_bus(name, target, &handler)
      Shoes::DisplayService.subscribe_to_event(name, target) { |*args, **_kwargs| handler.call(*args) }
    end

    # One subscription per event for all drawables rather than five per drawable: Lacci's
    # unsubscribe scans every subscription, which made clearing a big slot quadratic.
    def listen_to_drawables
      on_drawable_bus("prop_change") { |id, changes| prop_change(id, changes) }
      on_drawable_bus("destroy") { |id| destroyed(id) }
      on_drawable_bus("parent") { |id, parent_id| reparent(id, parent_id) }
      on_drawable_bus("focus") { |id| child.post(t: "focus", id: id) }
      on_drawable_bus("scroll_top") { |id, top| child.post(t: "scroll_to", id: id, top: Normalize.value(top)) }
    end

    # Only for drawables Rust knows about: a Para's text_items change arrives before its create.
    def on_drawable_bus(name, &handler)
      Shoes::DisplayService.subscribe_to_event(name, :any) do |*args, event_target: nil, **_kwargs|
        handler.call(event_target, *args) if event_target && display_drawable(event_target)
      end
    end

    def prop_change(id, changes)
      display = display_drawable(id) or return
      changes = changes.to_h.transform_keys(&:to_s)
      props = Normalize.props(display.kind, changes)
      display.update(props)
      child.post(t: "props", id: id, props: props)
      # A Flow's scroll_top= arrives as a prop change instead of the scroll_top event.
      child.post(t: "scroll_to", id: id, top: Normalize.value(changes["scroll_top"])) if changes.key?("scroll_top")
      timers.set_stopped(id, changes["stopped"], now: clock.now) if changes.key?("stopped")
    end

    # Rust drops the whole subtree, so we forget it too. Slot#remove does not cascade in Lacci,
    # and a timer inside a removed slot must stop with it.
    def destroyed(id)
      child.post(t: "destroy", id: id)
      display = display_drawable(id) or return
      display.detach
      display.subtree.each { |node| forget(node.id) }
    end

    def forget(id)
      timers.remove(id)
      @display_drawable_for.delete(id)
      Shoes::DisplayService.layout_cache.delete(id)
    end

    # Where Rust laid things out, [x, y, w, h, scroll_height] in window pixels by id, for
    # Lacci's left, top, width, height and scroll_height to read.
    def laid_out(rects)
      cache = Shoes::DisplayService.layout_cache
      Array(rects).each { |id, *rect| cache[id] = rect }
    end

    def reparent(id, parent_id)
      index = index_in_parent(id)
      display_drawable(id)&.attach_to(display_drawable(parent_id), index)
      child.post(t: "reparent", id: id, parent: parent_id, index: index)
    end

    # The app being run is the newest one not yet started. That is Shoes.APPS.last, except when
    # a Shoes.app nested in another's body ran first. An app counts as open from here, not from
    # its create: one whose block raises never gets this far.
    def run_latest_app
      Shoes::DisplayService.dispatch_event("custom_event_loop", nil, "return")
      app = Shoes.APPS.reverse.find { |candidate| !@open_apps.key?(candidate.linkable_id) } or return
      @open_apps[app.linkable_id] = true
      child.post(t: "run", app: app.linkable_id)
      child.flush
      @pump.install
    end

    # A nil-target destroy quits every app (Lacci binds every App to it). It can arrive from a
    # signal trap, where Mutexes are off limits, so this only flips flags; the pump sends the quit.
    def quit_all
      @open_apps.transform_values! { false }
    end

    # Apps are built and run inside one handler, so an app still unrun after a handler raised is
    # a `window` whose block raised. It never opens: Rust frees it and Shoes.APPS lets it go.
    def drop_unstarted_apps
      Shoes.APPS.reject { |app| @open_apps.key?(app.linkable_id) }.each do |app|
        Shoes.APPS.delete(app)
        app.destroy(send_event: false)
        free_app(app.linkable_id)
      end
    end

    # Rust frees the app's window and document, and its timers, drawables and layout go here.
    def free_app(app_id)
      child.post(t: "quit", app: app_id)
      timers.remove_app(app_id)
      @display_drawable_for.filter_map { |id, display| id if display.app_id == app_id }.each { |id| forget(id) }
    end

    def closed(app_id)
      return unless @open_apps[app_id]

      if @open_apps.count { |_id, open| open } == 1
        Shoes::DisplayService.dispatch_event("destroy", nil)
      else
        @open_apps[app_id] = false
        timers.remove_app(app_id)
        lacci_drawable(app_id)&.destroy(send_event: false)
      end
    end

    # Set the ivars directly: going through the setter would echo a prop_change back to Rust.
    def resized(app_id, width, height)
      app = lacci_drawable(app_id) or return
      app.instance_variable_set(:@width, width)
      app.instance_variable_set(:@height, height)
    end

    # Position among the Lacci parent's children, or nil for "append". Lacci already has the
    # child in place when it asks us to create it, which is what makes prepend come out right.
    # Appending is the common case, and checking for it first keeps a 16,000-line turtle drawing
    # from scanning its siblings once per line.
    def index_in_parent(id)
      drawable = lacci_drawable(id)
      siblings = drawable&.parent.respond_to?(:children) ? drawable.parent.children : nil
      return nil if siblings.nil? || siblings.last.equal?(drawable)

      siblings.index { |sibling| sibling.equal?(drawable) }
    end

    def app_id_for(kind, id, parent_id)
      case kind
      when "App" then id
      when "DocumentRoot" then id - 1
      else display_drawable(parent_id)&.app_id
      end
    end

    def display_drawable(id)
      id && query_display_drawable_for(id, nil_ok: true)
    end

    # Rust sends a ListBox choice as a String; hand Lacci the item it came from.
    def decode_args(name, target, args)
      return args unless name == "change"

      drawable = lacci_drawable(target)
      return args unless drawable.is_a?(Shoes::ListBox)

      [Array(drawable.items).find { |item| item.to_s == args.first } || args.first]
    end

    def lacci_drawable(id)
      id && Shoes::Drawable.drawable_by_id(id, none_ok: true)
    end

    def log_from_child(level, message)
      level = "info" unless Scarpe::Native::LogImpl::LEVELS.key?(level)
      @child_log.public_send(level, message)
    end

    def report_handler_error(error, context)
      app_frame = Array(error.backtrace).find do |frame|
        !frame.start_with?(*LIBRARY_DIRS) && !frame.include?("/gems/") && !frame.start_with?("<internal:")
      end
      @log.error("#{error.class}: #{error.message} in the #{context}#{" (at #{app_frame})" if app_frame}")
      @log.debug(Array(error.backtrace).join("\n"))
    end
  end
end
