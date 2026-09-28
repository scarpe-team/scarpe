# frozen_string_literal: true

require "scarpe/components/string_helpers"

module Scarpe::Native
  # Shoes-Spec for the native backend (DESIGN section 8). Test code runs in this process against
  # the real Lacci tree, once the first heartbeat after the app is up and painted has started its
  # slots. Clicks go through Rust's layout and hit-testing; the clock is frozen so timers move only
  # on advance(seconds).
  module Test
    def self.run_shoes_spec_test_code(code, class_name: nil, test_name: nil, filename: "(eval)", line: 1)
      raise Shoes::Errors::MultipleShoesSpecRunsError, "Scarpe Native runs one Shoes spec per process" if @started

      @started = true
      require "minitest"
      if ENV["SHOES_MINITEST_EXPORT_FILE"]
        require "scarpe/components/minitest_export_reporter"
        Minitest::Reporters::ShoesExportReporter.activate!
      end

      Shoes::DisplayService.display_service.spec_mode!
      define_test(code, class_name, test_name, filename, line)

      Scarpe::Native.after_first_heartbeat do
        DisplayService.instance.automation.frames(1)
        Minitest.run([])
      ensure
        Shoes.APPS.each(&:destroy)
      end
    end

    def self.define_test(code, class_name, test_name, filename, line)
      test_class = Class.new(SpecTest)
      Object.const_set(constant_name(class_name || ENV["SHOES_MINITEST_CLASS_NAME"] || "TestShoesSpecCode"), test_class)
      method_name = test_name || ENV["SHOES_MINITEST_METHOD_NAME"] || "test_shoes_spec"
      method_name = "test_#{method_name}" unless method_name.start_with?("test_")
      test_class.define_method(method_name) { eval(code, nil, filename, line) }
    end

    # Categories like "legacy/shoes-contrib/app" are not constant names until cleaned up.
    def self.constant_name(name)
      cleaned = Scarpe::Components::StringHelpers.camelize(name.to_s.gsub(/[^A-Za-z0-9_]/, "_"))
      cleaned.match?(/\A[A-Z]/) ? cleaned : "Test#{cleaned}"
    end
  end

  # Stands in for a Lacci drawable inside test code. Anything the drawable answers is forwarded,
  # so proxy.text, proxy.checked? and proxy.replace(...) are plain Lacci.
  class SpecProxy
    attr_reader :obj, :linkable_id, :display

    def initialize(obj)
      @obj = obj
      @linkable_id = obj.linkable_id
      @display = Shoes::DisplayService.display_service.query_display_drawable_for(@linkable_id)
    end

    # Through Rust's hit-testing, so it proves the drawable is laid out, visible and on top.
    # With arguments (a slot-level click subscription), it is dispatched as given.
    def trigger_click(*args)
      return trigger("click", *args) unless args.empty? && !@obj.is_a?(Shoes::SubscriptionItem)

      automation.click({ id: @linkable_id })
    end

    def trigger_hover
      return trigger("hover") if @obj.is_a?(Shoes::SubscriptionItem)

      automation.hover(@linkable_id)
    end

    def trigger_leave
      return trigger("leave") if @obj.is_a?(Shoes::SubscriptionItem)

      automation.leave(@linkable_id)
    end

    # Straight onto the bus, like a finished edit. For real typing use click_on + type_text.
    def trigger_change(value)
      trigger("change", value)
    end

    # Any display event, dispatched directly: trigger("animate", 3), trigger("keypress", ":left").
    # A handler that raises fails the test, as it would with Niente.
    def trigger(event_name, *args)
      Shoes::DisplayService.dispatch_event(event_name.to_s, @linkable_id, *args)
    end

    def layout
      automation.rect_of(@linkable_id)
    end

    def method_missing(method, ...)
      return super unless @obj.respond_to?(method)

      singleton_class.define_method(method) { |*args, **kwargs, &block| @obj.send(method, *args, **kwargs, &block) }
      send(method, ...)
    end

    def respond_to_missing?(method, include_private = false)
      @obj.respond_to?(method, include_private) || super
    end

    private

    def automation
      DisplayService.instance.automation
    end
  end

  # The Minitest class test code is evaluated in: Niente's finders, plus the native look-and-click API.
  class SpecTest < Minitest::Test
    TEXT_SIZES = %i[title banner caption subtitle tagline inscription].freeze

    def self.plural(name)
      name.match?(/(box|ss)\z/) ? "#{name}es" : "#{name}s"
    end

    Shoes::Drawable.drawable_classes.each do |drawable_class|
      name = drawable_class.dsl_name
      define_method(name) { |*specs| only(find_drawables(drawable_class, *specs), "#{name} matching #{specs.inspect}") }
      define_method(plural(name)) { |*specs| find_drawables(drawable_class, *specs).map { |d| proxy(d) } }
    end

    TEXT_SIZES.each do |size|
      define_method(size) { |*specs| only(sized_paras(size, specs), "#{size} matching #{specs.inspect}") }
      define_method(plural(size.to_s)) { |*specs| sized_paras(size, specs).map { |d| proxy(d) } }
    end

    def drawable(*specs)
      only(find_drawables(*specs), "drawable matching #{specs.inspect}")
    end

    def drawables(*specs)
      find_drawables(*specs).map { |d| proxy(d) }
    end
    alias_method :find_all, :drawables

    def find_button(text)
      button(text)
    end

    alias_method :all_ovals, :ovals
    alias_method :all_rects, :rects
    alias_method :all_buttons, :buttons
    alias_method :all_paras, :paras

    # Look and click

    def click_on(target, button: 1)
      automation.click(target_spec(target), button: button)
    end

    def click_at(x, y, button: 1)
      automation.click({ x: x, y: y }, button: button)
    end

    def hover_at(x, y)
      automation.mouse(:move, x, y)
    end
    alias_method :move_mouse, :hover_at

    # Presses at the first [x, y], moves through the rest with the button down and releases at
    # the last: every click, motion and release handler runs. No time passes (advance for that).
    def drag(*points, button: 1)
      raise ArgumentError, "drag needs two or more [x, y] points" if points.size < 2

      automation.mouse(:move, *points.first)
      automation.mouse(:down, *points.first, button: button)
      points.drop(1).each { |x, y| automation.mouse(:move, x, y) }
      automation.mouse(:up, *points.last, button: button)
    end

    def type_text(text)
      automation.type(text)
    end

    def press_key(name)
      automation.key(name)
    end

    def wheel(dy, x: nil, y: nil)
      app = Shoes.APPS.first
      automation.wheel(dy, x: x || app.width / 2.0, y: y || app.height / 2.0)
    end

    def layout_of(target)
      automation.rect_of(target_id(target))
    end

    def layout_tree
      automation.layout
    end

    def snapshot(name)
      path = Automation.snapshot_path(name)
      automation.snapshot(path)
      path
    end

    def pixel_at(x, y)
      automation.pixel(x, y)
    end

    def wait_frames(count = 1)
      automation.wait_frames(count)
    end

    def advance(seconds)
      automation.advance(seconds)
    end

    # Turns the event loop, in real time, until the block answers true, and fails the test after
    # `timeout` seconds. For news from outside the app, such as a program Shoes.run_program
    # started: the clock advance moves is frozen, but that news comes when it comes.
    def wait_until(timeout = 10, message = nil)
      service = DisplayService.instance
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      until yield
        flunk(message || "nothing came within #{timeout}s") if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        service.surfacing_handler_errors { service.pump.step }
      end
      true
    end

    def resize_window(width, height)
      automation.resize(width, height)
    end

    def focused_drawable
      id = automation.focused
      drawable = id && Shoes::Drawable.drawable_by_id(id, none_ok: true)
      drawable && proxy(drawable)
    end

    # What a screen reader meets (DESIGN 12): the window's Hash with Symbol keys (:role, :name,
    # :value, :toggled, :actions, :bounds...) and its nodes under :children. platform: true reads
    # what AppKit hands VoiceOver instead (:role, :subrole, :title, :value, :help), from a real window.
    def a11y_tree(platform: false)
      automation.a11y(platform: platform)
    end

    # Every node of a11y_tree, the window first, depth first.
    def a11y_nodes(platform: false)
      flatten = ->(node) { [node, *Array(node[:children]).flat_map(&flatten)] }
      flatten.call(a11y_tree(platform: platform))
    end

    # Acts on a node as a screen reader does. The target is a drawable, an id or a node Hash
    # from the tree; the action is :click, :focus, :set_value (give the value), :expand or :collapse.
    # platform: true goes through AppKit as VoiceOver does, and the target is the element's title.
    def a11y_action(target, action, value = nil, platform: false)
      return automation.platform_a11y_action(target, action, value: value) if platform

      id = target.is_a?(Hash) ? target.fetch(:id) : target_id(target)
      automation.a11y_action(id, action, value: value)
    end

    def stub_dialog(kind, value)
      builtins.stub(kind, value)
    end

    # [kind, message] for each dialog the app asked for.
    def dialogs_seen
      builtins.seen
    end

    # Webview Shoes-Spec compatibility. Its wait(seconds) is our advance; its stubs answer every call.
    def wait(seconds)
      advance(seconds)
    end

    def stub_alert
      builtins.stub_always(:alert, nil)
    end

    def stub_ask(returns: "")
      builtins.stub_always(:ask, returns)
    end

    def stub_confirm(returns: true)
      builtins.stub_always(:confirm, returns)
    end

    def stub_ask_color(returns: nil)
      builtins.stub_always(:ask_color, returns)
    end

    %w[ask_open_file ask_save_file ask_open_folder ask_save_folder].each do |kind|
      define_method("stub_#{kind}") { |returns: nil| builtins.stub_always(kind, returns) }
    end

    # The webview harness prepends these to test code; here there is nothing to time out or exit early.
    def timeout(_seconds = nil); end

    def exit_on_first_heartbeat; end

    private

    def automation
      DisplayService.instance.automation
    end

    def builtins
      DisplayService.instance.builtins
    end

    def proxy(drawable)
      SpecProxy.new(drawable)
    end

    def only(found, description)
      raise Shoes::Errors::MultipleDrawablesFoundError, "Found more than one #{description}!" if found.size > 1
      raise Shoes::Errors::NoDrawablesFoundError, "Found no #{description}!" if found.empty?

      proxy(found.first)
    end

    # Lacci understands classes, "@ivar", "$global" and "id:N". On top of those, a plain String
    # matches a drawable's text exactly and a Hash matches its attributes.
    def find_drawables(*specs)
      lacci_specs, our_specs = specs.partition { |spec| lacci_selector?(spec) }
      our_specs.reduce(Shoes::App.find_drawables_by(*lacci_specs)) do |found, spec|
        found.select { |drawable| matches?(drawable, spec) }
      end
    end

    def lacci_selector?(spec)
      spec.is_a?(Module) || ((spec.is_a?(String) || spec.is_a?(Symbol)) && spec.to_s.match?(/\A(\$|@|id:)/))
    end

    def matches?(drawable, spec)
      if spec.is_a?(Hash)
        spec.all? { |key, value| drawable.respond_to?(key) && drawable.public_send(key) == value }
      else
        drawable.respond_to?(:text) && drawable.text.to_s == spec.to_s
      end
    end

    def sized_paras(size, specs)
      find_drawables(Shoes::Para, *specs).select { |para| para.size == size }
    end

    def target_spec(target)
      target.is_a?(String) ? { text: target } : { id: target_id(target) }
    end

    def target_id(target)
      target.respond_to?(:linkable_id) ? target.linkable_id : Integer(target)
    end
  end
end
