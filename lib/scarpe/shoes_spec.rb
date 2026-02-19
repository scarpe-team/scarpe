# frozen_string_literal: true

require "minitest"
require "scarpe/cats_cradle"
require "scarpe/components/string_helpers"

require "scarpe/components/unit_test_helpers"

# Test framework code to allow Scarpe to execute Shoes-Spec test code.
# This will run inside the exe/scarpe child process, then send
# results back to the parent Minitest process.

# Dialog stubbing system for shoes-spec tests.
# Allows tests to mock alert, ask, confirm, and file dialogs
# so they don't block test execution.
module Scarpe::DialogStubs
  class << self
    # Storage for stub configurations
    def stubs
      @stubs ||= {}
    end

    # Clear all stubs (call between tests)
    def reset!
      @stubs = {}
    end

    # Check if a dialog is stubbed
    def stubbed?(dialog_name)
      stubs.key?(dialog_name)
    end

    # Get the stubbed return value for a dialog
    def get_stub(dialog_name)
      stubs[dialog_name]
    end

    # Set a stub for a dialog
    def stub(dialog_name, returns:)
      stubs[dialog_name] = returns
    end

    # Convenience methods for each dialog type
    def stub_alert
      stub(:alert, returns: nil)
    end

    def stub_ask(returns: "")
      stub(:ask, returns: returns)
    end

    def stub_confirm(returns: true)
      stub(:confirm, returns: returns)
    end

    def stub_ask_color(returns: "#000000")
      stub(:ask_color, returns: returns)
    end

    def stub_ask_open_file(returns: nil)
      stub(:ask_open_file, returns: returns)
    end

    def stub_ask_save_file(returns: nil)
      stub(:ask_save_file, returns: returns)
    end

    def stub_ask_open_folder(returns: nil)
      stub(:ask_open_folder, returns: returns)
    end

    def stub_ask_save_folder(returns: nil)
      stub(:ask_save_folder, returns: returns)
    end
  end
end

# Module to prepend to Shoes::Builtins for dialog interception.
# When a dialog is stubbed, returns the stubbed value immediately
# instead of dispatching to the display service.
module Scarpe::DialogStubsInterceptor
  def alert(message)
    if Scarpe::DialogStubs.stubbed?(:alert)
      Scarpe::DialogStubs.get_stub(:alert)
    else
      super
    end
  end

  def ask(message_string)
    if Scarpe::DialogStubs.stubbed?(:ask)
      Scarpe::DialogStubs.get_stub(:ask)
    else
      super
    end
  end

  def confirm(question)
    if Scarpe::DialogStubs.stubbed?(:confirm)
      Scarpe::DialogStubs.get_stub(:confirm)
    else
      super
    end
  end

  def ask_color(title_bar)
    if Scarpe::DialogStubs.stubbed?(:ask_color)
      Scarpe::DialogStubs.get_stub(:ask_color)
    else
      super
    end
  end

  def ask_open_file
    if Scarpe::DialogStubs.stubbed?(:ask_open_file)
      Scarpe::DialogStubs.get_stub(:ask_open_file)
    else
      super
    end
  end

  def ask_save_file
    if Scarpe::DialogStubs.stubbed?(:ask_save_file)
      Scarpe::DialogStubs.get_stub(:ask_save_file)
    else
      super
    end
  end

  def ask_open_folder
    if Scarpe::DialogStubs.stubbed?(:ask_open_folder)
      Scarpe::DialogStubs.get_stub(:ask_open_folder)
    else
      super
    end
  end

  def ask_save_folder
    if Scarpe::DialogStubs.stubbed?(:ask_save_folder)
      Scarpe::DialogStubs.get_stub(:ask_save_folder)
    else
      super
    end
  end
end

module Scarpe::Test
  # Is it at all reasonable to define more than one test to run in the same Shoes run? Probably not.
  # They'll leave in-memory residue.
  def self.run_shoes_spec_test_code(code, class_name: nil, test_name: nil)
    if @shoes_spec_init
      raise Shoes::Errors::MultipleShoesSpecRunsError, "Scarpe-Webview can only run a single Shoes spec per process!"
    end

    @shoes_spec_init = true

    # Install dialog stubbing interceptor if not already done
    install_dialog_stubs!

    # Reset any stubs from previous test runs
    Scarpe::DialogStubs.reset!

    require "scarpe/components/minitest_export_reporter"
    Minitest::Reporters::ShoesExportReporter.activate!

    class_name ||= ENV["SHOES_MINITEST_CLASS_NAME"] || "TestShoesSpecCode"
    test_name ||= ENV["SHOES_MINITEST_METHOD_NAME"] || "test_shoes_spec"

    Scarpe::CCInstance.include Scarpe::ShoesSpecTest

    Scarpe::CCInstance.instance.instance_eval do
      event_init

      t_timeout = ENV["SCARPE_SSPEC_TIMEOUT"] || "30"
      timeout(t_timeout.to_f) unless t_timeout.downcase == "none"

      on_event(:next_heartbeat) do
        Minitest.run ARGV

        wait_after = ENV["SCARPE_SSPEC_TIMEOUT_WAIT_AFTER_TEST"]
        if !(wait_after && wait_after.downcase != "n" && wait_after.downcase != "no")
          shut_down_shoes_code
        end
      end
    end

    test_class = Class.new(Minitest::Test)
    test_class.include Scarpe::ShoesSpecTest
    Object.const_set(Scarpe::Components::StringHelpers.camelize(class_name), test_class)
    test_name = "test_" + test_name unless test_name.start_with?("test_")
    test_class.define_method(test_name) do
      eval(code)
    end
  end

  # Install the dialog stubs interceptor by prepending to Shoes::Builtins.
  # Only does this once, even if called multiple times.
  def self.install_dialog_stubs!
    return if @dialog_stubs_installed

    @dialog_stubs_installed = true

    # Prepend our interceptor module to catch dialog calls
    Shoes::Builtins.prepend(Scarpe::DialogStubsInterceptor)
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
module Scarpe::ShoesSpecTest
  include Scarpe::Test::HTMLAssertions

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
      # Scarpe-Webview only supports a single Shoes::App instance
      app = Shoes.APPS[0]

      drawables = app.find_drawables_by(drawable_class, *args)
      raise Shoes::Errors::MultipleDrawablesFoundError, "Found more than one #{finder_name} matching #{args.inspect}!" if drawables.size > 1
      raise Shoes::Errors::NoDrawablesFoundError, "Found no #{finder_name} matching #{args.inspect}!" if drawables.empty?

      Scarpe::ShoesSpecProxy.new(drawables[0])
    end

    # Plural finder - returns array of all matches
    plural_name = pluralize_dsl_name(finder_name)
    define_method(plural_name) do |*args|
      app = Shoes.APPS[0]
      drawables = app.find_drawables_by(drawable_class, *args)
      drawables.map { |d| Scarpe::ShoesSpecProxy.new(d) }
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
      app = Shoes.APPS[0]
      drawables = app.find_drawables_by(Shoes::Para).select { |d| d.size == size_name }
      raise Shoes::Errors::MultipleDrawablesFoundError, "Found more than one #{size_name}!" if drawables.size > 1
      raise Shoes::Errors::NoDrawablesFoundError, "Found no #{size_name}!" if drawables.empty?

      Scarpe::ShoesSpecProxy.new(drawables[0])
    end

    # Plural finder - returns array of all matches
    define_method(pluralize_dsl_name(size_name.to_s)) do
      app = Shoes.APPS[0]
      drawables = app.find_drawables_by(Shoes::Para).select { |d| d.size == size_name }
      drawables.map { |d| Scarpe::ShoesSpecProxy.new(d) }
    end
  end

  # Singular drawable finder
  def drawable(*specs)
    app = Shoes.APPS[0]
    found = app.find_drawables_by(*specs)
    raise Shoes::Errors::MultipleDrawablesFoundError, "Found more than one drawable matching #{specs.inspect}!" if found.size > 1
    raise Shoes::Errors::NoDrawablesFoundError, "Found no drawable matching #{specs.inspect}!" if found.empty?

    Scarpe::ShoesSpecProxy.new(found[0])
  end

  # Plural drawables finder - returns array of all matches
  def drawables(*specs)
    app = Shoes.APPS[0]
    found = app.find_drawables_by(*specs)
    found.map { |d| Scarpe::ShoesSpecProxy.new(d) }
  end

  # Generic finder - returns array of all matching elements
  # Alias for drawables() for Shoes-Spec compatibility
  # @param specs [Array] search specifications (class, symbol, or string)
  # @return [Array<Scarpe::ShoesSpecProxy>] array of matching proxy objects
  # @example
  #   find_all(Shoes::Button)
  #   find_all(:@my_button)
  def find_all(*specs)
    drawables(*specs)
  end

  # Find a button by its text content
  # @param text [String] the button text to search for
  # @return [Scarpe::ShoesSpecProxy] proxy for the matching button
  # @raise [Shoes::Errors::NoDrawablesFoundError] if no button matches
  # @raise [Shoes::Errors::MultipleDrawablesFoundError] if multiple buttons match
  # @example
  #   find_button("Click Me")
  #   find_button("Submit").trigger_click
  def find_button(text)
    app = Shoes.APPS[0]
    all_buttons = app.find_drawables_by(Shoes::Button)
    matching = all_buttons.select { |b| b.text == text }

    raise Shoes::Errors::MultipleDrawablesFoundError, "Found more than one button with text #{text.inspect}!" if matching.size > 1
    raise Shoes::Errors::NoDrawablesFoundError, "Found no button with text #{text.inspect}!" if matching.empty?

    Scarpe::ShoesSpecProxy.new(matching[0])
  end

  # Aliases for consistency - some specs use all_* naming convention
  alias all_ovals ovals
  alias all_rects rects
  alias all_buttons buttons
  alias all_paras paras

  # Wait for a specified number of seconds, allowing animations/timers to run.
  # This is useful for testing time-based behavior like animate() or timer().
  # The wait happens asynchronously via heartbeat events, not a blocking sleep.
  #
  # @param seconds [Numeric] the number of seconds to wait
  # @return [void]
  # @example
  #   wait 0.1  # Wait 100ms for animation to progress
  #   wait 1.5  # Wait 1.5 seconds
  def wait(seconds)
    catscradle_dsl do
      wait timed_promise(seconds)
    end
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

  # A timeout won't cause an error by itself. If you want an error, make sure
  # to check for a minimum number of assertions or otherwise look for progress.
  def timeout(t_timeout = 5.0)
    catscradle_dsl do
      t0 = Time.now
      on_event(:every_heartbeat) do
        if Time.now - t0 >= t_timeout
          @log.info "Timed out after #{t_timeout} seconds!"
          shut_down_shoes_code
        end
      end
    end
  end

  def exit_on_first_heartbeat
    catscradle_dsl do
      on_event(:next_heartbeat) do
        @log.info "Exiting on first heartbeat (exit code #{exit_code})"
        exit 0
      end
    end
  end

  # === Dialog Stubbing Methods ===
  # These methods allow tests to mock dialog calls so they don't block.
  # Stubs must be set BEFORE the dialog is called (usually at test start).

  # Stub alert() to return nil without showing a dialog.
  # @example
  #   stub_alert
  #   button().trigger_click  # Won't block even if button calls alert()
  def stub_alert
    Scarpe::DialogStubs.stub_alert
  end

  # Stub ask() to return a specific value.
  # @param returns [String] the value ask() should return (default: "")
  # @example
  #   stub_ask(returns: "user input")
  #   assert_equal "user input", ask("What's your name?")
  def stub_ask(returns: "")
    Scarpe::DialogStubs.stub_ask(returns: returns)
  end

  # Stub confirm() to return true or false.
  # @param returns [Boolean] what confirm() should return (default: true)
  # @example
  #   stub_confirm(returns: false)
  #   refute confirm("Are you sure?")
  def stub_confirm(returns: true)
    Scarpe::DialogStubs.stub_confirm(returns: returns)
  end

  # Stub ask_color() to return a color string.
  # @param returns [String] the color value to return (default: "#000000")
  # @example
  #   stub_ask_color(returns: "#FF0000")
  def stub_ask_color(returns: "#000000")
    Scarpe::DialogStubs.stub_ask_color(returns: returns)
  end

  # Stub ask_open_file() to return a file path.
  # @param returns [String, nil] the path to return (default: nil)
  # @example
  #   stub_ask_open_file(returns: "/path/to/file.txt")
  def stub_ask_open_file(returns: nil)
    Scarpe::DialogStubs.stub_ask_open_file(returns: returns)
  end

  # Stub ask_save_file() to return a file path.
  # @param returns [String, nil] the path to return (default: nil)
  # @example
  #   stub_ask_save_file(returns: "/path/to/save.txt")
  def stub_ask_save_file(returns: nil)
    Scarpe::DialogStubs.stub_ask_save_file(returns: returns)
  end

  # Stub ask_open_folder() to return a folder path.
  # @param returns [String, nil] the path to return (default: nil)
  # @example
  #   stub_ask_open_folder(returns: "/path/to/folder")
  def stub_ask_open_folder(returns: nil)
    Scarpe::DialogStubs.stub_ask_open_folder(returns: returns)
  end

  # Stub ask_save_folder() to return a folder path.
  # @param returns [String, nil] the path to return (default: nil)
  # @example
  #   stub_ask_save_folder(returns: "/path/to/folder")
  def stub_ask_save_folder(returns: nil)
    Scarpe::DialogStubs.stub_ask_save_folder(returns: returns)
  end

  # Clear all dialog stubs. Useful if you need to reset mid-test.
  def reset_dialog_stubs
    Scarpe::DialogStubs.reset!
  end
end
