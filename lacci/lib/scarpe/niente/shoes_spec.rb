# frozen_string_literal: true

require "minitest"
require "scarpe/components/string_helpers"

module Niente; end

class Niente::Test
  def self.run_shoes_spec_test_code(code, class_name: nil, test_name: nil)
    if @shoes_spec_init
      raise Shoes::Errors::MultipleShoesSpecRunsError, "Niente can only run a single Shoes spec per process!"
    end
    @shoes_spec_init = true

    require "scarpe/components/minitest_export_reporter"
    Minitest::Reporters::ShoesExportReporter.activate!

    class_name ||= ENV["SHOES_MINITEST_CLASS_NAME"] || "TestShoesSpecCode"
    test_name ||= ENV["SHOES_MINITEST_METHOD_NAME"] || "test_shoes_spec"

    Shoes::DisplayService.subscribe_to_event("heartbeat", nil) do
      unless @hb_init
        Minitest.run []
        Shoes.APPS.each(&:destroy)
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
  # Helper to pluralize DSL names
  def self.pluralize_dsl_name(name)
    # Handle common English pluralization rules
    case name
    when /box$/
      # edit_box -> edit_boxes, list_box -> list_boxes
      name + "es"
    when /ss$/
      # progress -> progresses
      name + "es"
    else
      name + "s"
    end
  end

  Shoes::Drawable.drawable_classes.each do |drawable_class|
    finder_name = drawable_class.dsl_name

    # Singular finder - raises if not exactly one match
    define_method(finder_name) do |*args|
      drawables = Shoes::App.find_drawables_by(drawable_class, *args)

      raise Shoes::Errors::MultipleDrawablesFoundError, "Found more than one #{finder_name} matching #{args.inspect}!" if drawables.size > 1
      raise Shoes::Errors::NoDrawablesFoundError, "Found no #{finder_name} matching #{args.inspect}!" if drawables.empty?

      Niente::ShoesSpecProxy.new(drawables[0])
    end

    # Plural finder - returns array of all matches
    plural_name = pluralize_dsl_name(finder_name)
    define_method(plural_name) do |*args|
      drawables = Shoes::App.find_drawables_by(drawable_class, *args)
      drawables.map { |d| Niente::ShoesSpecProxy.new(d) }
    end
  end

  # Text size finders - these find Shoes::Para by size attribute
  # title(), banner(), caption(), subtitle(), tagline(), inscription()
  # are convenience methods that create Para with a specific size,
  # so we need special finders for them.
  TEXT_SIZE_NAMES = [:title, :banner, :caption, :subtitle, :tagline, :inscription].freeze

  TEXT_SIZE_NAMES.each do |size_name|
    # Singular finder - raises if not exactly one match
    define_method(size_name) do
      drawables = Shoes::App.find_drawables_by(Shoes::Para).select { |d| d.size == size_name }
      raise Shoes::Errors::MultipleDrawablesFoundError, "Found more than one #{size_name}!" if drawables.size > 1
      raise Shoes::Errors::NoDrawablesFoundError, "Found no #{size_name}!" if drawables.empty?

      Niente::ShoesSpecProxy.new(drawables[0])
    end

    # Plural finder - returns array of all matches
    define_method(pluralize_dsl_name(size_name.to_s)) do
      drawables = Shoes::App.find_drawables_by(Shoes::Para).select { |d| d.size == size_name }
      drawables.map { |d| Niente::ShoesSpecProxy.new(d) }
    end
  end

  # Singular drawable finder
  def drawable(*specs)
    found = Shoes::App.find_drawables_by(*specs)
    raise Shoes::Errors::MultipleDrawablesFoundError, "Found more than one drawable matching #{specs.inspect}!" if found.size > 1
    raise Shoes::Errors::NoDrawablesFoundError, "Found no drawable matching #{specs.inspect}!" if found.empty?
    Niente::ShoesSpecProxy.new(found[0])
  end

  # Plural drawables finder - returns array of all matches
  def drawables(*specs)
    found = Shoes::App.find_drawables_by(*specs)
    found.map { |d| Niente::ShoesSpecProxy.new(d) }
  end

  # Generic finder - returns array of all matching elements
  # Alias for drawables() for Shoes-Spec compatibility
  # @param specs [Array] search specifications (class, symbol, or string)
  # @return [Array<Niente::ShoesSpecProxy>] array of matching proxy objects
  # @example
  #   find_all(Shoes::Button)
  #   find_all(:@my_button)
  def find_all(*specs)
    drawables(*specs)
  end

  # Find a button by its text content
  # @param text [String] the button text to search for
  # @return [Niente::ShoesSpecProxy] proxy for the matching button
  # @raise [Shoes::Errors::NoDrawablesFoundError] if no button matches
  # @raise [Shoes::Errors::MultipleDrawablesFoundError] if multiple buttons match
  # @example
  #   find_button("Click Me")
  #   find_button("Submit").trigger_click
  def find_button(text)
    all_buttons = Shoes::App.find_drawables_by(Shoes::Button)
    matching = all_buttons.select { |b| b.text == text }

    raise Shoes::Errors::MultipleDrawablesFoundError, "Found more than one button with text #{text.inspect}!" if matching.size > 1
    raise Shoes::Errors::NoDrawablesFoundError, "Found no button with text #{text.inspect}!" if matching.empty?

    Niente::ShoesSpecProxy.new(matching[0])
  end

  # Aliases for consistency - some specs use all_* naming convention
  alias all_ovals ovals
  alias all_rects rects
  alias all_buttons buttons
  alias all_paras paras
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
