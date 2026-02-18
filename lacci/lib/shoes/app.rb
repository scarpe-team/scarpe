# frozen_string_literal: true

class Shoes
  class App < Shoes::Drawable
    include Shoes::Log

    # The Shoes root of the drawable tree
    attr_reader :document_root

    # The application directory for this app. Often this will be the directory
    # containing the launched application file.
    attr_reader :dir

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

    init_args
    def initialize(
      title: 'Shoes!',
      width: 480,
      height: 420,
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
      @dir = Dir.pwd

      @do_shutdown = false
      @event_loop_type = 'displaylib' # the default

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

      @slots = []

      @content_container = nil

      @routes = {}

      super

      # This creates the DocumentRoot, including its corresponding display drawable
      Drawable.with_current_app(self) do
        @document_root = Shoes::DocumentRoot.new
      end

      # Now create the App display drawable
      create_display_drawable

      # Set up testing *after* Display Service basic objects exist

      if ENV['SHOES_SPEC_TEST'] && !Shoes::App.set_test_code
        test_code = File.read ENV['SHOES_SPEC_TEST']
        unless test_code.empty?
          Shoes::App.set_test_code = true
          Shoes::Spec.instance.run_shoes_spec_test_code test_code
        end
      end

      @app_code_body = app_code_body

      # Try to de-dup as much as possible and not send repeat or multiple
      # destroy events
      @watch_for_destroy = bind_shoes_event(event_name: 'destroy') do
        Shoes::DisplayService.unsub_from_events(@watch_for_destroy) if @watch_for_destroy
        @watch_for_destroy = nil
        destroy(send_event: false)
      end

      @watch_for_event_loop = bind_shoes_event(event_name: 'custom_event_loop') do |loop_type|
        unless CUSTOM_EVENT_LOOP_TYPES.include?(loop_type)
          raise(Shoes::Errors::InvalidAttributeValueError,
                "Unknown event loop type: #{loop_type.inspect}!")
        end

        @event_loop_type = loop_type
      end

      Signal.trap('INT') do
        @log.warn('App interrupted by signal, stopping...')
        puts "\nStopping Shoes app..."
        destroy
      end
    end

    def init
      send_shoes_event(event_name: 'init')
      return if @do_shutdown

      with_slot(@document_root, &@app_code_body)
      render_index_if_defined_on_first_boot

      # Fire any registered start callbacks after the app code has run
      fire_start_callbacks
    end

    # Register a callback to run after the app finishes initializing.
    # In Shoes3, this is used to do things that need to happen after the UI is ready.
    #
    # @yield the block to call when the app starts
    def start(&block)
      @start_callbacks ||= []
      @start_callbacks << block
    end

    private

    def fire_start_callbacks
      return unless @start_callbacks

      @start_callbacks.each do |callback|
        with_slot(@document_root) { instance_eval(&callback) }
      end
    end

    public

    # "Container" drawables like flows, stacks, masks and the document root
    # are considered "slots" in Shoes parlance. When a new slot is created,
    # we push it here in order to track what drawables are found in that slot.
    def push_slot(slot)
      @slots.push(slot)
    end

    def pop_slot
      return if @slots.size <= 1

      @slots.pop
    end

    def current_slot
      @slots[-1]
    end

    # Shoes3 compatibility: app.slot returns the current slot
    alias_method :slot, :current_slot

    # Track external (non-Shoes) callers from Slot#append so that
    # method_missing can fall back to them. This enables Shoes3-compatible
    # patterns like HH::SideTab where methods defined on the caller
    # (e.g. `content`) need to be reachable from inside instance_eval'd blocks.
    def push_external_self(obj)
      @external_self_stack ||= []
      @external_self_stack.push(obj)
    end

    def pop_external_self
      @external_self_stack&.pop
    end

    def external_self
      @external_self_stack&.last
    end

    def with_slot(slot_item, &block)
      return unless block_given?

      push_slot(slot_item)
      instance_eval(&block)
    ensure
      pop_slot
    end

    # We use method_missing for drawable-creating methods like "button".
    # The parent's method_missing will auto-create Shoes style getters and setters.
    # This is similar to the method_missing in Shoes::Slot, but different in
    # where the new drawable appears.
    #
    # When an external_self is active (from Slot#append), unknown methods are
    # delegated to that external object. This provides Shoes3-compatible
    # method dispatch for non-Shoes callers.
    def method_missing(name, *args, **kwargs, &block)
      klass = ::Shoes::Drawable.drawable_class_by_name(name)
      if !klass && external_self && external_self.respond_to?(name)
        return external_self.send(name, *args, **kwargs, &block)
      end
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
      if @do_shutdown
        warn 'Destroy has already been signaled, but we just called Shoes::App.run!'
        return
      end

      # The display lib can send us an event to customise the event loop handling.
      # But it must do so before the "run" event returns.
      send_shoes_event(event_name: 'run')

      case @event_loop_type
      when 'wait'
        # Display lib wants us to busy-wait instead of it.
        Shoes::DisplayService.dispatch_event('heartbeat', nil) until @do_shutdown
      when 'displaylib'
        # If run event returned, that means we're done.
        destroy
      when 'return'
        # We can just return to the main event loop. But we shouldn't call destroy.
        # Presumably some event loop *outside* our event loop is handling things.
      else
        raise Shoes::Errors::InvalidAttributeValueError,
              "Internal error! Incorrect event loop type: #{@event_loop_type.inspect}!"
      end
    end

    def destroy(send_event: true)
      @do_shutdown = true
      send_shoes_event(event_name: 'destroy') if send_event
    end

    # Close the application window. This is an alias for destroy
    # that matches Shoes3 API.
    alias close destroy

    def all_drawables
      out = []

      to_add = [@document_root, @document_root.children]
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
      @pages ||= {}
      @pages[name] = proc do
        stack(width: 1.0, height: 1.0) do
          instance_eval(&block)
        end
      end
    end

    def visit(name_or_path)
      # First, check for exact page match (symbol)
      if @pages && @pages[name_or_path]
        @document_root.clear do
          instance_eval(&@pages[name_or_path])
        end
        return
      end

      # Second, check URL routes
      route, method_name = @routes.find { |r, _| r === name_or_path }
      if route
        @document_root.clear do
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
        if @pages && @pages[page_name]
          @document_root.clear do
            instance_eval(&@pages[page_name])
          end
          return
        end
      end

      puts "Error: URL '#{name_or_path}' not found"
    end

    def url(path, method_name)
      if path.is_a?(String) && path.include?('(')
        # Convert string patterns to regex
        regex = Regexp.new("^#{path.gsub(/\(.*?\)/, '(.*?)')}$")
        @routes[regex] = method_name
      else
        @routes[path] = method_name
      end
    end
  end
end

# Event handler DSLs get defined in both App and Slot - same code, slightly different results
events = %i[motion hover leave click release keypress wheel animate every timer]
events.each do |event|
  Shoes::App.define_method(event) do |*args, &block|
    subscription_item(args:, shoes_api_name: event.to_s, &block)
  end
  Shoes::Slot.define_method(event) do |*args, &block|
    subscription_item(args:, shoes_api_name: event.to_s, &block)
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

  # Draw Context methods -- forward to the current slot
  %i[fill nofill stroke strokewidth nostroke rotate scale skew].each do |dc_method|
    define_method(dc_method) do |*args|
      current_slot.send(dc_method, *args)
    end
  end

  # Slot methods that should be accessible at App level.
  # In Shoes, the app block's self has direct access to these slot methods
  # because the app body evaluates as if it were inside the document_root slot.
  def clear(&block)
    current_slot.clear(&block)
  end

  def contents
    current_slot.contents
  end

  def append(&block)
    current_slot.append(&block)
  end

  def prepend(&block)
    current_slot.prepend(&block)
  end

  # Returns the current mouse state as [button, x, y].
  # button is 1 if the left mouse button is held down, 0 otherwise.
  # x and y are the mouse coordinates relative to the app window.
  def mouse
    Shoes::DisplayService.mouse_state
  end

  # Read the system clipboard contents.
  # Returns the clipboard text as a string, or "" if empty/unavailable.
  def clipboard
    if RUBY_PLATFORM =~ /darwin/
      `pbpaste 2>/dev/null`.to_s
    elsif RUBY_PLATFORM =~ /linux/
      `xclip -selection clipboard -o 2>/dev/null`.to_s
    else
      ""
    end
  rescue
    ""
  end

  # Write text to the system clipboard.
  def clipboard=(text)
    if RUBY_PLATFORM =~ /darwin/
      IO.popen("pbcopy", "w") { |p| p.write(text.to_s) }
    elsif RUBY_PLATFORM =~ /linux/
      IO.popen("xclip -selection clipboard", "w") { |p| p.write(text.to_s) }
    end
    text
  rescue
    text
  end

  # Set the window title dynamically.
  # @param new_title [String] the new window title
  def title=(new_title)
    self.set_shoes_style("title", new_title.to_s)
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

  alias info puts
  alias debug puts

  # Returns the app's scrollbar gutter width (the width of the scrollbar).
  # In classic Shoes this is typically 28 pixels.
  def gutter
    28
  end

  # Canvas transform: translate the coordinate system.
  # This is a draw-context operation that shifts drawing by (x, y).
  def translate(x, y)
    # Forward to current slot's draw context if available
    # For now, this is a no-op stub that prevents errors.
    # Full implementation requires display service support.
  end

  # Arc_to draws an arc within a shape block.
  def arc_to(cx, cy, w, h, start_angle, end_angle)
    return unless current_slot.is_a?(::Shoes::Shape)

    current_slot.add_shape_command(['arc_to', cx, cy, w, h, start_angle, end_angle])
  end

  # Cap style for line drawing (e.g., :curve, :rect, :project)
  def cap(style)
    # Draw context cap style - no-op stub for compatibility
  end

  # Open a new app window. In classic Shoes, `window` is like `Shoes.app` but
  # sets the child window's `owner` to the launching app.
  def window(**opts, &block)
    Shoes.app(**opts.merge(owner: self), &block)
  end

  # Open a dialog-style window. In classic Shoes, this is like `window` but
  # with dialog box styling. Sets the owner like `window`.
  def dialog(**opts, &block)
    Shoes.app(**opts.merge(owner: self), &block)
  end

  # Quit the application. This is an App-level alias for Shoes.quit
  # that allows `quit` or `self.quit` from within an app block.
  def quit
    Shoes.quit
  end

  # Exit is an alias for quit, matching Shoes3 API.
  alias exit quit

  private

  def render_index_if_defined_on_first_boot
    return if @first_boot_finished

    visit('/') if @routes['/'] == :index

    @first_boot_finished = true
  end
end
