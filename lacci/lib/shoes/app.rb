# frozen_string_literal: true

module Shoes
  class App < Shoes::Widget
    include Shoes::Log

    class << self
      attr_accessor :instance
    end

    attr_reader :document_root

    display_properties :title, :width, :height, :resizable, :debug

    def initialize(
      title: "Scarpe!",
      width: 480,
      height: 420,
      resizable: true,
      debug: ENV["SCARPE_DEBUG"] ? true : false,
      &app_code_body
    )
      if Shoes::App.instance
        @log.error("Trying to create a second Shoes::App in the same process! Fail!")
        raise "Cannot create multiple Shoes::App objects!"
      else
        Shoes::App.instance = self
      end

      log_init("Shoes::App")

      @do_shutdown = false

      super

      # This creates the DocumentRoot, including its corresponding display widget
      @document_root = Scarpe::DocumentRoot.new

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

      Signal.trap("INT") do
        @log.warning("App interrupted by signal, stopping...")
        puts "\nStopping Scarpe app..."
        destroy
      end
    end

    def init
      send_shoes_event(event_name: "init")
      return if @do_shutdown

      ::Shoes::App.instance.with_slot(@document_root, &@app_code_body)
    end

    # "Container" widgets like flows, stacks, masks and the document root
    # are considered "slots" in Scarpe parlance. When a new slot is created,
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

    # This isn't supposed to return. The display service should take control
    # of the main thread. Local Webview even stops any background threads.
    def run
      if @do_shutdown
        $stderr.puts "Destroy has already been signaled, but we just called Shoes::App.run!"
        return
      end
      send_shoes_event(event_name: "run")
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
        to_add = to_add.flat_map(&:children).compact
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
        elsif spec.is_a?(Symbol)
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
            if app.instance_variables.include?(spec)
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

  alias_method :info, :puts
end
