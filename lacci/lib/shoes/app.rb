# frozen_string_literal: true

class Shoes
  class App < Shoes::Drawable
    include Shoes::Log

    # An app's block runs with the App as self, so the app's instance variables and Lacci's
    # live on one object. Lacci's own start with an underscore (@_slots, @_pages), the way a
    # Rails view keeps @_request and @_routes, so an app can have @slots or @pages of its own.

    # The Shoes root of the drawable tree
    def document_root
      @_document_root
    end

    # The application directory for this app. Often this will be the directory
    # containing the launched application file.
    def dir
      @_dir
    end

    # The owner app that spawned this window (if any).
    # In Shoes, when you call `window` from inside an app, the new window's
    # `owner` method returns the parent app.
    attr_reader :owner

    shoes_styles :title, :width, :height, :resizable, :features, :opacity, :cursor, :owner

    # This is defined to avoid the linkable-id check in the Shoes-style method_missing def'n
    attr_reader :features

    # These are the allowed values for custom_event_loop events.
    #
    # * displaylib means the display library is not going to return from running the app
    # * return means the display library will return and the loop will be handled outside Lacci's control
    # * wait means Lacci should busy-wait and send eternal heartbeats from the "run" event
    #
    # If the display service grabs control and keeps it, Webview-style, that means "displaylib"
    # should be the value. A Scarpe-Wasm-style "return" is appropriate if the code can finish
    # without Ruby ending the process at the end of the source file. A "wait" can prevent Ruby
    # from finishing early, but also prevents multiple applications. Only "return" will normally
    # allow multiple Shoes applications.
    CUSTOM_EVENT_LOOP_TYPES = %w[displaylib return wait]

    class << self
      attr_accessor :set_test_code
    end

    # Shoes 3 and Shoes 4 both open a 600x500 window titled "Shoes" (ledger A1, Q1).
    DEFAULT_TITLE = "Shoes"
    DEFAULT_WIDTH = 600
    DEFAULT_HEIGHT = 500

    init_args
    def initialize(
      title: DEFAULT_TITLE,
      width: DEFAULT_WIDTH,
      height: DEFAULT_HEIGHT,
      resizable: true,
      features: [],
      owner: nil,
      &app_code_body
    )
      log_init('Shoes::App')

      if Shoes::FEATURES.include?(:multi_app) || Shoes.APPS.empty?
        Shoes.APPS.push self
      else
        @log.error('Trying to create a second Shoes::App in the same process! Fail!')
        raise Shoes::Errors::TooManyInstancesError, 'Cannot create multiple Shoes::App objects!'
      end

      # We cd to the app's containing dir when running the app
      @_dir = Dir.pwd

      @_do_shutdown = false
      @_event_loop_type = 'displaylib' # the default

      @features = features
      @owner = owner

      unknown_ext = features - Shoes::FEATURES - Shoes::EXTENSIONS
      unsupported_features = unknown_ext & Shoes::KNOWN_FEATURES
      unless unsupported_features.empty?
        @log.error("Shoes app requires feature(s) not supported by this display service: #{unsupported_features.inspect}!")
        raise Shoes::Errors::UnsupportedFeatureError, "Shoes app needs features: #{unsupported_features.inspect}"
      end
      unless unknown_ext.empty?
        @log.warn("Shoes app requested unknown features #{unknown_ext.inspect}! Known: #{(Shoes::FEATURES + Shoes::EXTENSIONS).inspect}")
      end

      @_slots = []

      @_content_container = nil

      @_routes = {}

      super

      # This creates the DocumentRoot, including its corresponding display drawable
      Drawable.with_current_app(self) do
        @_document_root = Shoes::DocumentRoot.new
      end

      # Now create the App display drawable
      create_display_drawable

      # Set up testing *after* Display Service basic objects exist

      if ENV['SHOES_SPEC_TEST'] && !Shoes::App.set_test_code
        test_code = File.read ENV['SHOES_SPEC_TEST']
        unless test_code.empty?
          Shoes::App.set_test_code = true
          Shoes::Spec.instance.run_shoes_spec_test_code test_code, filename: ENV['SHOES_SPEC_TEST'], line: 1
        end
      end

      @_app_code_body = app_code_body

      # Try to de-dup as much as possible and not send repeat or multiple
      # destroy events
      @_watch_for_destroy = bind_shoes_event(event_name: 'destroy') do
        Shoes::DisplayService.unsub_from_events(@_watch_for_destroy) if @_watch_for_destroy
        @_watch_for_destroy = nil
        destroy(send_event: false)
      end

      @_watch_for_event_loop = bind_shoes_event(event_name: 'custom_event_loop') do |loop_type|
        unless CUSTOM_EVENT_LOOP_TYPES.include?(loop_type)
          raise(Shoes::Errors::InvalidAttributeValueError,
                "Unknown event loop type: #{loop_type.inspect}!")
        end

        @_event_loop_type = loop_type
      end

      Signal.trap('INT') do
        @log.warn('App interrupted by signal, stopping...')
        puts "\nStopping Shoes app..."
        destroy
      end
    end

    def init
      send_shoes_event(event_name: 'init')
      return if @_do_shutdown

      # The app block is the one that changes self (manual 208-214); slot blocks keep it (B1).
      with_slot(@_document_root) { instance_eval(&@_app_code_body) } if @_app_code_body
      show_root_route_on_first_boot

      # Fire any registered start callbacks after the app code has run
      fire_start_callbacks
    end

    # Register a callback to run after the app finishes initializing.
    # In Shoes3, this is used to do things that need to happen after the UI is ready.
    # Inside a slot's block, start belongs to that slot (ledger H8).
    #
    # @yield the block to call when the app starts
    def start(&block)
      return current_slot.start(&block) unless current_slot.equal?(@_document_root)

      @_start_callbacks ||= []
      @_start_callbacks << block
    end

    # finish inside a slot's block belongs to that slot (ledger H8).
    def finish(&block)
      current_slot.finish(&block)
    end

    private

    def fire_start_callbacks
      return unless @_start_callbacks

      @_start_callbacks.each do |callback|
        with_slot(@_document_root) { instance_eval(&callback) }
      end
    end

    public

    # "Container" drawables like flows, stacks, masks and the document root
    # are considered "slots" in Shoes parlance. When a new slot is created,
    # we push it here in order to track what drawables are found in that slot.
    def push_slot(slot)
      @_slots.push(slot)
    end

    def pop_slot
      return if @_slots.size <= 1

      @_slots.pop
    end

    def current_slot
      @_slots[-1]
    end

    # Shoes3 compatibility: app.slot returns the current slot
    alias_method :slot, :current_slot

    # Runs a slot's block with that slot pushed on the app's editing stack (manual 322-324).
    # The block keeps its own self, as Shoes 3 calls it plainly (s3_canvas.c:650-653, ledger
    # B1): a widget or a plain object keeps its instance variables and methods inside its
    # stacks, and the DSL calls it sends to the App, or to a widget, land in the slot.
    def with_slot(slot_item)
      return unless block_given?

      push_slot(slot_item)
      @__editing_depth = editing_depth + 1
      begin
        yield
      ensure
        @__editing_depth -= 1
        pop_slot
      end
    end

    # How many slot blocks are running: none between events, one or more while an app, a slot
    # or an append builds something, as Shoes 3's nesting stack is empty or not. (The app's
    # own instance variables are its user's, hence the underscores.)
    def editing_depth
      @__editing_depth || 0
    end

    # We use method_missing for drawable-creating methods like "button".
    # The parent's method_missing will auto-create Shoes style getters and setters.
    # This is similar to the method_missing in Shoes::Slot, but different in
    # where the new drawable appears.
    def method_missing(name, *args, **kwargs, &block)
      klass = ::Shoes::Drawable.drawable_class_by_name(name)
      return super unless klass

      ::Shoes::App.define_method(name) do |*args, **kwargs, &block|
        # Shoes3 compat: when a Hash is passed as the last positional arg
        # (common when routed through method_missing without **kwargs),
        # extract it as keyword args for drawable initialization.
        if kwargs.empty? && args.last.is_a?(Hash)
          kwargs = args.pop
        end
        Drawable.with_current_app(self) do
          klass.new(*args, **kwargs, &block)
        end
      end

      # Also apply the same Hash extraction for this first call
      if kwargs.empty? && args.last.is_a?(Hash)
        kwargs = args.pop
      end
      send(name, *args, **kwargs, &block)
    end

    # Get the current draw context for the current slot
    #
    # @return [Hash] a hash of Shoes styles for the current draw context
    def current_draw_context
      current_slot&.current_draw_context
    end

    # This usually doesn't return. The display service may take control
    # of the main thread. Local Webview even stops any background threads.
    # However, some display libraries don't want to shut down and don't
    # want to (and/or can't) take control of the event loop.
    def run
      if @_do_shutdown
        warn 'Destroy has already been signaled, but we just called Shoes::App.run!'
        return
      end

      # The app block has built the window; from here the window is open.
      @_started = true

      # The display lib can send us an event to customise the event loop handling.
      # But it must do so before the "run" event returns.
      send_shoes_event(event_name: 'run')

      case @_event_loop_type
      when 'wait'
        # Display lib wants us to busy-wait instead of it.
        Shoes::DisplayService.dispatch_event('heartbeat', nil) until @_do_shutdown
      when 'displaylib'
        # If run event returned, that means we're done.
        destroy
      when 'return'
        # We can just return to the main event loop. But we shouldn't call destroy.
        # Presumably some event loop *outside* our event loop is handling things.
      else
        raise Shoes::Errors::InvalidAttributeValueError,
              "Internal error! Incorrect event loop type: #{@_event_loop_type.inspect}!"
      end
    end

    # Whether the window is open: false while the app block is still building it
    # (manual 1006-1010, ledger M26).
    def started?
      @_started ? true : false
    end

    # The URL of the page on show (manual 980-982, ledger J1). Apps start at "/".
    def location
      @_location || "/"
    end

    def destroy(send_event: true)
      @_do_shutdown = true
      finish_slots
      send_shoes_event(event_name: 'destroy') if send_event
    end

    # Closes this app's window only (manual 901-904, ledger A8): while another window is open the
    # app goes on there, and this one leaves Shoes.APPS (manual 887-888). The display hears a
    # destroy aimed at this app. The last window to close takes everything with it, as destroy does.
    def close
      return destroy unless Shoes.APPS.any? { |app| !app.equal?(self) && app.started? }

      @_do_shutdown = true
      Shoes.APPS.delete(self)
      send_self_event(event_name: 'destroy')
    end

    def all_drawables
      out = []

      to_add = [@_document_root, @_document_root.children]
      until to_add.empty?
        out.concat(to_add)
        to_add = to_add.flat_map { |w| w.respond_to?(:children) ? w.children : [] }.compact
      end

      out
    end

    # We can add various ways to find drawables here.
    # These are sort of like Shoes selectors, used for testing.
    # This method finds a drawable across all active Shoes apps.
    def self.find_drawables_by(*specs)
      Shoes.APPS.flat_map do |app|
        app.find_drawables_by(*specs)
      end
    end

    # We can add various ways to find drawables here.
    # These are sort of like Shoes selectors, used for testing.
    def find_drawables_by(*specs)
      drawables = all_drawables
      specs.each do |spec|
        if spec == Shoes::App
          drawables = [@app]
        elsif spec.is_a?(Class)
          drawables.select! { |w| spec === w }
        elsif spec.is_a?(Symbol) || spec.is_a?(String)
          s = spec.to_s
          case s[0]
          when '$'
            begin
              # I'm not finding a global_variable_get or similar...
              global_value = eval s
              drawables &= [global_value]
            rescue
              # raise Shoes::Errors::InvalidAttributeValueError, "Error getting global variable: #{spec.inspect}"
              drawables = []
            end
          when '@'
            if @app.instance_variables.include?(spec.to_sym)
              drawables &= [@app.instance_variable_get(spec)]
            else
              # raise Shoes::Errors::InvalidAttributeValueError, "Can't find top-level instance variable: #{spec.inspect}!"
              drawables = []
            end
          else
            unless s.start_with?('id:')
              raise Shoes::Errors::InvalidAttributeValueError, "Don't know how to find drawables by #{spec.inspect}!"
            end

            find_id = Integer(s[3..-1])
            drawable = Shoes::Drawable.drawable_by_id(find_id)
            drawables &= [drawable]

          end
        else
          raise(Shoes::Errors::InvalidAttributeValueError, "Don't know how to find drawables by #{spec.inspect}!")
        end
      end
      drawables
    end

    def page(name, &block)
      @_pages ||= {}
      @_pages[name] = proc do
        stack(width: 1.0, height: 1.0) do
          instance_eval(&block)
        end
      end
    end

    def visit(name_or_path)
      @_location = name_or_path.is_a?(Symbol) ? "/#{name_or_path}" : name_or_path.to_s

      # First, check for exact page match (symbol)
      if @_pages && @_pages[name_or_path]
        show_page do
          instance_eval(&@_pages[name_or_path])
        end
        return
      end

      # Second, check URL routes
      route, method_name = @_routes.find { |r, _| r === name_or_path }
      if route
        show_page do
          if route.is_a?(Regexp)
            match_data = route.match(name_or_path)
            send(method_name, *match_data.captures)
          else
            send(method_name)
          end
        end
        return
      end

      # Third, if it's a string path like "/page2", try matching page :page2
      if name_or_path.is_a?(String) && name_or_path.start_with?("/")
        page_name = name_or_path[1..-1].to_sym  # "/page2" -> :page2
        if @_pages && @_pages[page_name]
          show_page do
            instance_eval(&@_pages[page_name])
          end
          return
        end
      end

      puts "Error: URL '#{name_or_path}' not found"
    end

    # A new page starts from nothing. Unlike clear, the old page's timers and event
    # handlers go too, as Shoes 3 resets the whole canvas on visit (s3_canvas.c:282-303).
    def show_page(&block)
      @_document_root.contents.each(&:destroy)
      @_document_root.clear(&block)
    end
    private :show_page

    def url(path, method_name)
      if path.is_a?(String) && path.include?('(')
        # Convert string patterns to regex
        regex = Regexp.new("^#{path.gsub(/\(.*?\)/, '(.*?)')}$")
        @_routes[regex] = method_name
      else
        @_routes[path] = method_name
      end
    end
  end
end

# Event handler DSLs get defined in both App and Slot - same code, slightly different results.
# Timers return the timer, so it can be stopped; event handlers return self (manual 2187-2284).
%i[animate every timer].each do |timer|
  [Shoes::App, Shoes::Slot].each do |owner|
    owner.define_method(timer) do |*args, &block|
      subscription_item(args:, shoes_api_name: timer.to_s, &block)
    end
  end
end

# A slot keeps one handler per event, so giving it another replaces the first (ledger H6).
%i[motion hover leave click release keypress wheel].each do |event|
  [Shoes::App, Shoes::Slot].each do |owner|
    owner.define_method(event) do |*args, &block|
      subscription_item(args:, shoes_api_name: event.to_s, &block).replace_earlier_handlers
      self
    end
  end
end

# These methods will need to be defined on Slots too, but probably need a rework in general.
class Shoes::App < Shoes::Drawable
  # This is going to go away. See issue #496
  def background(...)
    current_slot.background(...)
  end

  # This is going to go away. See issue #498
  def border(...)
    current_slot.border(...)
  end

  # Draw Context methods -- forward to the current slot. fill and stroke return the
  # pattern (manual: fill(pattern) » pattern); the rest return self.
  %i[fill stroke].each do |dc_method|
    define_method(dc_method) do |*args|
      current_slot.send(dc_method, *args)
    end
  end

  %i[nofill nostroke strokewidth rotate scale skew translate transform cap].each do |dc_method|
    define_method(dc_method) do |*args|
      current_slot.send(dc_method, *args)
      self
    end
  end

  # Slot methods that should be accessible at App level.
  # In Shoes, the app block's self has direct access to these slot methods
  # because the app body evaluates as if it were inside the document_root slot.
  # Like the slot's own, they return self.
  def clear(&block)
    current_slot.clear(&block)
    self
  end

  def contents
    current_slot.contents
  end

  def append(&block)
    current_slot.append(&block)
    self
  end

  def prepend(&block)
    current_slot.prepend(&block)
    self
  end

  def before(drawable, &block)
    current_slot.before(drawable, &block)
    self
  end

  def after(drawable, &block)
    current_slot.after(drawable, &block)
    self
  end

  # Returns the current mouse state as [button, x, y].
  # button is 1 if the left mouse button is held down, 0 otherwise.
  # x and y are the mouse coordinates relative to the app window.
  def mouse
    Shoes::DisplayService.mouse_state_of(linkable_id)
  end

  # The system clipboard's text, the one every program cuts and pastes through (manual 891),
  # or "" when it is empty or cannot be read. A display with a clipboard of its own answers
  # (the native renderer does); for the others Lacci asks the system (Shoes::Clipboard).
  def clipboard
    shoes_builtin("clipboard").to_s
  end

  # Puts text on the system clipboard (manual 897).
  def clipboard=(text)
    shoes_builtin("clipboard=", text.to_s)
    text
  end

  # Set the window title dynamically.
  # @param new_title [String] the new window title
  def title=(new_title)
    style(title: new_title.to_s)
  end

  # Shoes3-compatible method to set the window title.
  # @param new_title [String] the new window title
  def set_window_title(new_title)
    self.title = new_title
  end

  # Shape DSL methods

  def move_to(x, y)
    unless x.is_a?(Numeric) && y.is_a?(Numeric)
      raise(Shoes::Errors::InvalidAttributeValueError,
            'Pass only Numeric arguments to move_to!')
    end

    return unless current_slot.is_a?(::Shoes::Shape)

    current_slot.add_shape_command(['move_to', x, y])
  end

  def line_to(x, y)
    unless x.is_a?(Numeric) && y.is_a?(Numeric)
      raise(Shoes::Errors::InvalidAttributeValueError,
            'Pass only Numeric arguments to line_to!')
    end

    return unless current_slot.is_a?(::Shoes::Shape)

    current_slot.add_shape_command(['line_to', x, y])
  end

  # Draw a cubic Bézier curve within a shape block.
  # cx1, cy1: first control point; cx2, cy2: second control point; x, y: end point.
  def curve_to(cx1, cy1, cx2, cy2, x, y)
    [cx1, cy1, cx2, cy2, x, y].each do |v|
      unless v.is_a?(Numeric)
        raise(Shoes::Errors::InvalidAttributeValueError,
              'Pass only Numeric arguments to curve_to!')
      end
    end

    return unless current_slot.is_a?(::Shoes::Shape)

    current_slot.add_shape_command(['curve_to', cx1, cy1, cx2, cy2, x, y])
  end

  # In an app's blocks info and debug print as puts does, as they did in Shoes 3's apps, and
  # reach the Shoes console too (ledger K3).
  def info(*messages)
    messages.each { |message| Shoes::Console.log(:info, message) }
    puts(*messages)
  end

  def debug(*messages)
    messages.each { |message| Shoes::Console.log(:debug, message) }
    puts(*messages)
  end

  # Image effects (Shoes 3's blur, glow and shadow on image(w, h) { } canvases) are an
  # extension no display draws yet (ledger E9); they must not stop the app.
  %i[blur glow shadow].each do |effect|
    define_method(effect) { |*_args, **_opts| self }
  end

  # Returns the app's scrollbar gutter width (the width of the scrollbar).
  # In classic Shoes this is typically 28 pixels.
  def gutter
    28
  end

  # Arc_to draws an arc within a shape block.
  def arc_to(cx, cy, w, h, start_angle, end_angle)
    return unless current_slot.is_a?(::Shoes::Shape)

    current_slot.add_shape_command(['arc_to', cx, cy, w, h, start_angle, end_angle])
  end

  # Open a new app window. In classic Shoes, `window` is like `Shoes.app` but
  # sets the child window's `owner` to the launching app. Its styles may come as
  # a Hash too, as Shoes.app's may (ledger A10).
  def window(styles = {}, **opts, &block)
    Shoes.app(styles, **opts, owner: self, &block)
  end

  # Open a dialog-style window. In classic Shoes, this is like `window` but
  # with dialog box styling. Sets the owner like `window`.
  def dialog(styles = {}, **opts, &block)
    Shoes.app(styles, **opts, owner: self, &block)
  end

  # Quit the application. This is an App-level alias for Shoes.quit
  # that allows `quit` or `self.quit` from within an app block.
  def quit
    Shoes.quit
  end

  # Exit is an alias for quit, matching Shoes3 API.
  alias exit quit

  private

  # A closing window tells every slot in it that it is going, as Shoes 3 does (ledger H8): the
  # window's own slot first (shoes_app_remove, s3_app.c:107-114), then each slot as it is
  # removed, after the slots inside it (s3_canvas.c:481-495), hidden ones too. Once per app,
  # however it closes. A finish block that raises is logged, and the window closes anyway.
  def finish_slots
    return if @_slots_finished || @_document_root.nil?

    @_slots_finished = true
    ([@_document_root] + slots_inside(@_document_root)).each do |slot|
      slot.fire_finish_callbacks
    rescue StandardError, ScriptError => e
      @log.error("A finish block raised #{e.class}: #{e.message} as its window closed")
    end
  end

  # Every slot below this one, each after the slots inside it.
  def slots_inside(slot)
    Array(slot.children).grep(Shoes::Slot).flat_map { |child| slots_inside(child) + [child] }
  end

  # Apps start at "/" (ledger J1), whatever method it routes to: url.rb routes it to
  # :setupscreen.
  def show_root_route_on_first_boot
    return if @_first_boot_finished

    visit("/") if @_routes.any? { |route, _| route === "/" }

    @_first_boot_finished = true
  end
end
