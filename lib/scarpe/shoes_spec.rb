# frozen_string_literal: true

require "minitest"
require "scarpe/cats_cradle"
require "scarpe/components/string_helpers"

require "scarpe/components/unit_test_helpers"

# Test framework code to allow Scarpe to execute Shoes-Spec test code.
# This will run inside the exe/scarpe child process, then send
# results back to the parent Minitest process.

module Scarpe::Test
  # Is it at all reasonable to define more than one test to run in the same Shoes run? Probably not.
  # They'll leave in-memory residue.
  def self.run_shoes_spec_test_code(code, class_name: nil, test_name: nil)
    if @shoes_spec_init
      raise Shoes::Errors::MultipleShoesSpecRunsError, "Scarpe-Webview can only run a single Shoes spec per process!"
    end

    @shoes_spec_init = true

    require "scarpe/components/minitest_export_reporter"
    Minitest::Reporters::ShoesExportReporter.activate!

    class_name ||= ENV["SHOES_MINITEST_CLASS_NAME"] || "TestShoesSpecCode"
    test_name ||= ENV["SHOES_MINITEST_METHOD_NAME"] || "test_shoes_spec"

    Scarpe::CCInstance.instance.instance_eval do
      on_event(:next_heartbeat) do
        Minitest.run ARGV

        shut_down_shoes_code
      end
    end

    test_class = Class.new(Scarpe::ShoesSpecTest)
    Object.const_set(Scarpe::Components::StringHelpers.camelize(class_name), test_class)
    test_name = "test_" + test_name unless test_name.start_with?("test_")
    test_class.define_method(test_name) do
      eval(code)
    end
  end
end

class Scarpe::ShoesSpecProxy
  attr_reader :obj
  attr_reader :linkable_id
  attr_reader :display

  JS_EVENTS = [:click, :hover, :leave, :change]

  def initialize(obj)
    @obj = obj
    @linkable_id = obj.linkable_id
    @display = ::Shoes::DisplayService.display_service.query_display_drawable_for(obj.linkable_id)

    unless @display
      raise "Can't find display widget for #{obj.inspect}!"
    end
  end

  def method_missing(method, ...)
    if @obj.respond_to?(method)
      self.singleton_class.define_method(method) do |*args, **kwargs, &block|
        @obj.send(method, *args, **kwargs, &block)
      end
      send(method, ...)
    else
      super # raise an exception
    end
  end

  def trigger(event_name, *args)
    name = "#{@linkable_id}-#{event_name}"
    Scarpe::Webview::DisplayService.instance.app.handle_callback(name, *args)
  end

  JS_EVENTS.each do |ev|
    define_method "trigger_#{ev}" do |*args|
      trigger(ev, *args)
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @obj.respond_to_missing?(method_name, include_private)
  end
end

# When running ShoesSpec tests, we create a parent class for all of them
# with the appropriate convenience methods and accessors.
class Scarpe::ShoesSpecTest < Minitest::Test
  include Scarpe::Test::HTMLAssertions

  Shoes::Drawable.drawable_classes.each do |drawable_class|
    finder_name = drawable_class.dsl_name

    define_method(finder_name) do |*args|
      app = Shoes::App.instance

      drawables = app.find_drawables_by(drawable_class, *args)
      raise Shoes::Errors::MultipleDrawablesFoundError, "Found more than one #{finder_name} matching #{args.inspect}!" if drawables.size > 1
      raise Shoes::Errors::NoDrawablesFoundError, "Found no #{finder_name} matching #{args.inspect}!" if drawables.empty?

      Scarpe::ShoesSpecProxy.new(drawables[0])
    end
  end
  def drawable(*specs)
    drawables = app.find_drawables_by(*specs)
    raise Scarpe::MultipleDrawablesFoundError, "Found more than one #{finder_name} matching #{args.inspect}!" if drawables.size > 1
    raise Scarpe::NoDrawablesFoundError, "Found no #{finder_name} matching #{args.inspect}!" if drawables.empty?

    Scarpe::ShoesSpecProxy.new(drawables[0])
  end

  def catscradle_dsl(&block)
    Scarpe::CCInstance.instance.instance_eval(&block)
  end

  def dom_html
    catscradle_dsl do
      wait fully_updated
      dom_html
    end
  end

  # This isn't working. Neither is calling die_after. Are the other fibers not
  # running or something like that? Should run a test from the command line
  # and see what's happening... Or check logfiles?
  def timeout(t_timeout = 5.0, exit_code: -1)
    catscradle_dsl do
      t0 = Time.now
      on_event(:every_heartbeat) do
        if Time.now - t0 >= t_timeout
          if exit_code == 0
            @log.info "Timed out after #{t_timeout} seconds!"
          else
            @log.error "Timed out after #{t_timeout} seconds!"
          end
          exit exit_code
        end
      end
    end
  end

  def exit_on_first_heartbeat(exit_code: 0)
    catscradle_dsl do
      on_event(:next_heartbeat) do
        @log.info "Exiting on first heartbeat (exit code #{exit_code})"
        exit exit_code
      end
    end
  end
end
