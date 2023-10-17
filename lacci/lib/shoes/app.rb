# frozen_string_literal: true

module Shoes
  # The main class for creating Shoes applications.
  class App < Shoes::Drawable
    include Shoes::Log

    class << self
      attr_accessor :instance
    end

    # @return [Object] The root of the document for this application.
    attr_reader :document_root

    shoes_styles :title, :width, :height, :resizable

    CUSTOM_EVENT_LOOP_TYPES = ["displaylib", "return", "wait"]

    # @param title [String] The title of the application window.
    # @param width [Integer] The width of the application window.
    # @param height [Integer] The height of the application window.
    # @param resizable [Boolean] Set to `true` to allow window resizing.
    # @see https://github.com/scarpe-team/scarpe/tree/main/docs/examples/app.rb
    def initialize(
      title: "Shoes!",
      width: 480,
      height: 420,
      resizable: true,
      &app_code_body
    )
      log_init("Shoes::App")

      # Initializes the Shoes application.

      # Checks if another Shoes::App instance already exists in the same process.
      if Shoes::App.instance
        @log.error("Trying to create a second Shoes::App in the same process! Fail!")
        raise Scarpe::TooManyInstancesError, "Cannot create multiple Shoes::App objects!"
      else
        Shoes::App.instance = self
      end

      @do_shutdown = false
      @event_loop_type = "displaylib" # the default

      super

      # The draw context tracks current settings like fill and stroke,
      # plus potentially other current state that changes from drawable
      # to drawable and slot to slot.
      @draw_context = {
        "fill" => "",
        "stroke" => "",
        "rotate" => 0,
      }

      # This creates the DocumentRoot, including its corresponding display drawable
      @document_root = Shoes::DocumentRoot.new

      @slots = []

      # Now create the App display drawable
      create_display_drawable

      # Set up testing events *after* Display Service basic objects exist
      if ENV["SCARPE_APP_TEST"]
        test_code = File.read ENV["SCARPE_APP_TEST"]
        if test_code != ""
          @test_obj = Object.new
          @test_obj.instance_eval test_code
        end
      end

      if ENV["SHOES_SPEC_TEST"]
        require "scarpe/components/minitest_export_reporter"
        Minitest::Reporters::ShoesExportReporter.activate!
        test_code = File.read ENV["SHOES_SPEC_TEST"]
        unless test_code.empty?
          kwargs = {}
          kwargs[:class_name] = ENV["SHOES_MINITEST_CLASS_NAME"] if ENV["SHOES_MINITEST_CLASS_NAME"]
          kwargs[:test_name] = ENV["SHOES_MINITEST_METHOD_NAME"] if ENV["SHOES_MINITEST_METHOD_NAME"]
          Shoes::Spec.instance.run_shoes_spec_test_code test_code, **kwargs
        end
      end

      @app_code_body = app_code_body

      # Try to de-dup as much as possible and not send repeat or multiple
      # destroy events
      @watch_for_destroy = bind_shoes_event(event_name: "destroy") do
        Shoes::DisplayService.unsub_from_events(@watch_for_destroy) if @watch_for_destroy
        @watch_for_destroy = nil
        self.destroy(send_event: false)
      end

      @watch_for_event_loop = bind_shoes_event(event_name: "custom_event_loop") do |loop_type|
        raise(InvalidAttributeValueError, "Unknown event loop type: #{loop_type.inspect}!") unless CUSTOM_EVENT_LOOP_TYPES.include?(loop_type)

        @event_loop_type = loop_type
      end

      Signal.trap("INT") do
        @log.warn("App interrupted by signal, stopping...")
        puts "\nStopping Shoes app..."
        destroy
      end
    end

    # Initializes the application.
    def init
      # Sends the "init" event.
      send_shoes_event(event_name: "init")
      return if @do_shutdown

      ::Shoes::App.instance.with_slot(@document_root, &@app_code_body)
    end

    # "Container" drawables like flows, stacks, masks and the document root
    # are considered "slots" in Shoes parlance. When a new slot is created,
    # we push it here in order to track what drawables are found in that slot.
    # Pushes a new slot onto the stack.
    def push_slot(slot)
      # Pushes a new slot onto the stack.
      @slots.push(slot)
    end

    # Pops the last slot from the slots stack.
    def pop_slot
      return if @slots.size <= 1

      @slots.pop
    end

    # Returns the current slot.
    # @return [Drawable] The current slot.
    def current_slot
      @slots[-1]
    end

    # Executes a block within a specific slot.
    def with_slot(slot_item, &block)
      return unless block_given?

      push_slot(slot_item)
      Shoes::App.instance.instance_eval(&block)
    ensure
      pop_slot
    end

    # Returns a copy of the current drawing context.
    # @return [Hash] The current drawing context.
    def current_draw_context
      @draw_context.dup
    end

    # This usually doesn't return. The display service may take control
    # of the main thread. Local Webview even stops any background threads.
    # However, some display libraries don't want to shut down and don't
    # want to (and/or can't) take control of the event loop.
    def run
      if @do_shutdown
        $stderr.puts "Destroy has already been signaled, but we just called Shoes::App.run!"
        return
      end

      # The display lib can send us an event to customise the event loop handling.
      # But it must do so before the "run" event returns.
      send_shoes_event(event_name: "run")

      case @event_loop_type
      when "wait"
        # Display lib wants us to busy-wait instead of it.
        sleep 0.1 until @do_shutdown
      when "displaylib"
        # If run event returned, that means we're done.
        destroy
      when "return"
        # We can just return to the main event loop. But we shouldn't call destroy.
        # Presumably some event loop *outside* our event loop is handling things.
      else
        raise InvalidAttributeValueError, "Internal error! Incorrect event loop type: #{@event_loop_type.inspect}!"
      end
    end

    # Signals the application to destroy itself.
    # @param send_event [Boolean] Set to `true` to send a "destroy" event.
    def destroy(send_event: true)
      @do_shutdown = true
      send_shoes_event(event_name: "destroy") if send_event
    end

    # Retrieves all drawables within the application.
    # @return [Array<Drawable>] An array of all drawables in the application.
    def all_drawables
      out = []

      to_add = @document_root.children
      until to_add.empty?
        out.concat(to_add)
        to_add = to_add.flat_map { |w| w.respond_to?(:children) ? w.children : [] }.compact
      end

      out
    end

    # We can add various ways to find drawables here.
    # These are sort of like Shoes selectors, used for testing.
    # @param specs [Array] An array of criteria for finding drawables.
    # @return [Array<Drawable>] An array of drawables that match the criteria.
    def find_drawables_by(*specs)
      drawables = all_drawables
      specs.each do |spec|
        if spec.is_a?(Class)
          drawables.select! { |w| spec === w }
        elsif spec.is_a?(Symbol) || spec.is_a?(String)
          s = spec.to_s
          case s[0]
          when "$"
            begin
              # I'm not finding a global_variable_get or similar...
              global_value = eval s
              drawables &= [global_value]
            rescue
              raise InvalidAttributeValueError, "Error getting global variable: #{spec.inspect}"
            end
          when "@"
            if Shoes::App.instance.instance_variables.include?(spec.to_sym)
              drawables &= [self.instance_variable_get(spec)]
            else
              raise InvalidAttributeValueError, "Can't find top-level instance variable: #{spec.inspect}!"
            end
          else
          end
        else
          raise(InvalidAttributeValueError, "Don't know how to find drawables by #{spec.inspect}!")
        end
      end
      drawables
    end
  end
end

# DSL methods
class Shoes::App
  # Sets the background of the current slot.
  def background(...)
    current_slot.background(...)
  end

  # Sets the border of the current slot.
  def border(...)
    current_slot.border(...)
  end

  # Defines event handler methods for various events.
  events = [:motion, :hover, :leave, :click, :release, :keypress, :animate, :every, :timer]
  events.each do |event|
    define_method(event) do |*args, &block|
      subscription_item(args:, shoes_api_name: event.to_s, &block)
    end
  end
  # Draw context methods
  # Sets the fill color in the drawing context.
  def fill(color)
    @draw_context["fill"] = color
  end

  # Clears the fill color in the drawing context.
  def nofill
    @draw_context["fill"] = ""
  end

  # Sets the stroke color in the drawing context.
  def stroke(color)
    @draw_context["stroke"] = color
  end

  # Clears the stroke color in the drawing context.
  def nostroke
    @draw_context["stroke"] = ""
  end
  # Shape DSL methods
  # Moves the current slot to the specified coordinates.
  def move_to(x, y)
    raise(InvalidAttributeValueError, "Pass only Numeric arguments to move_to!") unless x.is_a?(Numeric) && y.is_a?(Numeric)

    if current_slot.is_a?(::Shoes::Shape)
      current_slot.add_shape_command(["move_to", x, y])
    end
  end

  # Draws a line from the current position to the specified coordinates.
  def line_to(x, y)
    raise(InvalidAttributeValueError, "Pass only Numeric arguments to line_to!") unless x.is_a?(Numeric) && y.is_a?(Numeric)

    if current_slot.is_a?(::Shoes::Shape)
      current_slot.add_shape_command(["line_to", x, y])
    end
  end

  # Rotates the current slot by the specified angle.
  def rotate(angle)
    @draw_context["rotate"] = angle
  end

  # Not implemented yet: curve_to, arc_to

  # Outputs information to the console.
  alias_method :info, :puts
end
