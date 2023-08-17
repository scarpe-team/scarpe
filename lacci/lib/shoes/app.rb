# frozen_string_literal: true

module Shoes
  class App < Shoes::Widget
    include Shoes::Log

    class << self
      attr_accessor :instance
    end

    attr_reader :document_root

    display_properties :title, :width, :height, :resizable

    CUSTOM_EVENT_LOOP_TYPES = ["displaylib", "return", "wait"]

    def initialize(
      title: "Shoes!",
      width: 480,
      height: 420,
      resizable: true,
      &app_code_body
    )
      log_init("Shoes::App")

      if Shoes::App.instance
        @log.error("Trying to create a second Shoes::App in the same process! Fail!")
        raise "Cannot create multiple Shoes::App objects!"
      else
        Shoes::App.instance = self
      end

      @do_shutdown = false
      @event_loop_type = "displaylib" # the default

      super

      # The draw context tracks current settings like fill and stroke,
      # plus potentially other current state that changes from widget
      # to widget and slot to slot.
      @draw_context = {
        "fill" => "",
        "stroke" => "",
      }

      # This creates the DocumentRoot, including its corresponding display widget
      @document_root = Shoes::DocumentRoot.new

      @slots = []

      # Now create the App display widget
      create_display_widget

      # Set up testing events *after* Display Service basic objects exist
      if ENV["SCARPE_APP_TEST"]
        test_code = File.read ENV["SCARPE_APP_TEST"]
        if test_code != ""
          self.instance_eval test_code
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
        raise("Unknown event loop type: #{loop_type.inspect}!") unless CUSTOM_EVENT_LOOP_TYPES.include?(loop_type)

        @event_loop_type = loop_type
      end

      Signal.trap("INT") do
        @log.warn("App interrupted by signal, stopping...")
        puts "\nStopping Shoes app..."
        destroy
      end
    end

    def init
      send_shoes_event(event_name: "init")
      return if @do_shutdown

      ::Shoes::App.instance.with_slot(@document_root, &@app_code_body)
    end

    # "Container" widgets like flows, stacks, masks and the document root
    # are considered "slots" in Shoes parlance. When a new slot is created,
    # we push it here in order to track what widgets are found in that slot.
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

    def with_slot(slot_item, &block)
      return unless block_given?

      push_slot(slot_item)
      Shoes::App.instance.instance_eval(&block)
    ensure
      pop_slot
    end

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
        raise "Internal error! Incorrect event loop type: #{@event_loop_type.inspect}!"
      end
    end

    def destroy(send_event: true)
      @do_shutdown = true
      send_shoes_event(event_name: "destroy") if send_event
    end

    def all_widgets
      out = []

      to_add = @document_root.children
      until to_add.empty?
        out.concat(to_add)
        to_add = to_add.flat_map { |w| w.respond_to?(:children) ? w.children : [] }.compact
      end

      out
    end

    # We can add various ways to find widgets here.
    # These are sort of like Shoes selectors, used for testing.
    def find_widgets_by(*specs)
      widgets = all_widgets
      specs.each do |spec|
        if spec.is_a?(Class)
          widgets.select! { |w| spec === w }
        elsif spec.is_a?(Symbol) || spec.is_a?(String)
          s = spec.to_s
          case s[0]
          when "$"
            begin
              # I'm not finding a global_variable_get or similar...
              global_value = eval s
              widgets &= [global_value]
            rescue
              raise "Error getting global variable: #{spec.inspect}"
            end
          when "@"
            if Shoes::App.instance.instance_variables.include?(spec.to_sym)
              widgets &= [self.instance_variable_get(spec)]
            else
              raise "Can't find top-level instance variable: #{spec.inspect}!"
            end
          else
          end
        else
          raise("Don't know how to find widgets by #{spec.inspect}!")
        end
      end
      widgets
    end
  end
end

# DSL methods
class Shoes::App
  def background(...)
    current_slot.background(...)
  end

  def border(...)
    current_slot.border(...)
  end

  def motion(&block)
    subscription_item(shoes_api_name: "motion", &block)
  end

  def hover(&block)
    subscription_item(shoes_api_name: "hover", &block)
  end

  def click(&block)
    subscription_item(shoes_api_name: "click", &block)
  end

  # Draw context methods

  def fill(color)
    @draw_context["fill"] = color
  end

  def nofill
    @draw_context["fill"] = ""
  end

  def stroke(color)
    @draw_context["stroke"] = color
  end

  def nostroke
    @draw_context["stroke"] = ""
  end

  # Shape DSL methods

  def move_to(x, y)
    raise("Pass only Numeric arguments to move_to!") unless x.is_a?(Numeric) && y.is_a?(Numeric)

    if current_slot.is_a?(::Shoes::Shape)
      current_slot.add_shape_command(["move_to", x, y])
    end
  end

  def line_to(x, y)
    raise("Pass only Numeric arguments to line_to!") unless x.is_a?(Numeric) && y.is_a?(Numeric)

    if current_slot.is_a?(::Shoes::Shape)
      current_slot.add_shape_command(["line_to", x, y])
    end
  end

  # Not implemented yet: curve_to, arc_to

  alias_method :info, :puts
end
