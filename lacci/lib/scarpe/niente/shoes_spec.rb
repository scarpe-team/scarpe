# frozen_string_literal: true

require "minitest"
require "scarpe/components/string_helpers"

module Niente; end

class Niente::Test
  def self.run_shoes_spec_test_code(code, class_name: nil, test_name: nil)
    if @shoes_spec_init
      raise Shoes::Errors::MultipleShoesSpecRunsError, "Scarpe-Webview can only run a single Shoes spec per process!"
    end
    @shoes_spec_init = true

    require "scarpe/components/minitest_export_reporter"
    Minitest::Reporters::ShoesExportReporter.activate!

    class_name ||= ENV["SHOES_MINITEST_CLASS_NAME"] || "TestShoesSpecCode"
    test_name ||= ENV["SHOES_MINITEST_METHOD_NAME"] || "test_shoes_spec"

    Shoes::DisplayService.subscribe_to_event("heartbeat", nil) do
      unless @hb_init
        Minitest.run []
        Shoes::App.instance.destroy
      end
      @hb_init = true
    end

    test_class = Class.new(Niente::ShoesSpecTest)
    Object.const_set(Scarpe::Components::StringHelpers.camelize(class_name), test_class)
    test_name = "test_" + test_name unless test_name.start_with?("test_")
    test_class.define_method(test_name) do
      eval(code)
    end
  end
end

class Niente::ShoesSpecTest < Minitest::Test
  Shoes::Drawable.drawable_classes.each do |drawable_class|
    finder_name = drawable_class.dsl_name

    define_method(finder_name) do |*args|
      app = Shoes::App.instance

      drawables = app.find_drawables_by(drawable_class, *args)
      raise Shoes::Errors::MultipleDrawablesFoundError, "Found more than one #{finder_name} matching #{args.inspect}!" if drawables.size > 1
      raise Shoes::Errors::NoDrawablesFoundError, "Found no #{finder_name} matching #{args.inspect}!" if drawables.empty?

      Niente::ShoesSpecProxy.new(drawables[0])
    end
  end

  def drawable(*specs)
    drawables = Shoes::App.instance.find_drawables_by(*specs)
    raise Shoes::Errors::MultipleDrawablesFoundError, "Found more than one #{finder_name} matching #{args.inspect}!" if drawables.size > 1
    raise Shoes::Errors::NoDrawablesFoundError, "Found no #{finder_name} matching #{args.inspect}!" if drawables.empty?
    Niente::ShoesSpecProxy.new(drawables[0])
  end
end

class Niente::ShoesSpecProxy
  attr_reader :obj
  attr_reader :linkable_id
  attr_reader :display

  def initialize(obj)
    @obj = obj
    @linkable_id = obj.linkable_id
    @display = ::Shoes::DisplayService.display_service.query_display_drawable_for(obj.linkable_id)
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

  JS_EVENTS = [:click, :hover, :leave]
  JS_EVENTS.each do |event|
    define_method("trigger_#{event}") do |*args, **kwargs|
      ::Shoes::DisplayService.dispatch_event(event.to_s, @linkable_id, *args, **kwargs)
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @obj.respond_to_missing?(method_name, include_private)
  end
end
