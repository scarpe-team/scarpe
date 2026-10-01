# frozen_string_literal: true

# We're separating Shoes from Scarpe, a little at a time. This should be requirable
# without using Scarpe at all.
#
# The Lacci gem is like the old Shoes-core from Shoes4: a way
# to handle the DSL and command-line parts of Shoes without knowing anything about how the
# display side works at all.

if RUBY_VERSION[0..2] < '3.2'
  Shoes::Log.logger('Shoes').error('Lacci (Scarpe, Shoes) requires Ruby 3.2 or higher!')
  exit(-1)
end

class Shoes; end
class Shoes::Error < StandardError; end
require_relative 'shoes/errors'

require_relative 'shoes/constants'
require_relative 'shoes/ruby_extensions'
require_relative 'shoes/compat_require'

# Shoes adds some top-level methods and constants that can be used everywhere. Kernel is where they go.
module Kernel
  include Shoes::Constants
end

require_relative 'shoes/display_service'

# Pre-declare classes that get referenced outside their own require file
class Shoes::Drawable < Shoes::Linkable; end
class Shoes::Slot < Shoes::Drawable; end
class Shoes::Widget < Shoes::Slot; end

require_relative 'shoes/log'
require_relative 'shoes/pattern'
require_relative 'shoes/color'
require_relative 'shoes/colors'

require_relative 'shoes/font_file'
require_relative 'shoes/error_report'
require_relative 'shoes/console'
require_relative 'shoes/clipboard'
require_relative 'shoes/builtins'

require_relative 'shoes/background'

require_relative 'shoes/drawable'
require_relative 'shoes/art'
require_relative 'shoes/draw_context'
require_relative 'shoes/app'
require_relative 'shoes/drawables'
# Turtle graphics is loaded on-demand via `require 'scarpe/turtle'`
# Not auto-loaded since most apps don't use it

# Expose Shoes drawable classes as top-level constants for classic Shoes compatibility.
# In Shoes, `style(Link, stroke: black)` works without the Shoes:: prefix.
Link = Shoes::Link unless defined?(Link)
LinkHover = Shoes::LinkHover unless defined?(LinkHover)
Window = Shoes::App unless defined?(Window)

require_relative 'shoes/download'
require_relative 'shoes/program'

# No easy way to tell at this point whether
# we will later load Shoes-Spec code, e.g.
# by running a segmented app with test code.
require_relative 'shoes-spec'

# The module containing Shoes in all its glory.
# Shoes is a platform-independent GUI library, designed to create
# small visual applications in Ruby.
#
class Shoes
  class << self
    attr_accessor :APPS

    # Track the most recently defined Shoes subclass for the inheritance pattern
    # e.g., class Book < Shoes; end; Shoes.app
    attr_accessor :pending_app_class

    # When someone does `class MyApp < Shoes`, track it
    def inherited(subclass)
      # Only track direct subclasses of Shoes, not Shoes::App, Shoes::Drawable, etc.
      # Those have their own inheritance tracking
      if self == ::Shoes
        Shoes.pending_app_class = subclass
      end
      super
    end

    TEXT_MODES = %i[scarpe shoes3].freeze

    # How text is sized and set, for every window the program opens. :scarpe, the default,
    # reads a text size as pixels and sets text in the system's sans (ledger M14). :shoes3 sets
    # it as Shoes 3 did: a size is points at 96 dpi, so a para's 12 draws 16 px tall, and a text
    # block that names no face gets Arial (s3t_textblock.c:293, s3_world.c:46-48). It is for
    # programs laid out for Shoes 3's text, such as Hackety Hack; set it before the first window.
    #
    # @return [Symbol] :scarpe or :shoes3
    def text_mode
      @text_mode || :scarpe
    end

    # @param mode [Symbol, String] :scarpe or :shoes3
    def text_mode=(mode)
      mode = mode.to_s.delete_prefix(":").to_sym
      raise ArgumentError, "Shoes.text_mode is :scarpe or :shoes3, not #{mode.inspect}" unless TEXT_MODES.include?(mode)

      @text_mode = mode
      Shoes::DisplayService.dispatch_event("text_mode", nil, mode.to_s) if defined?(Shoes::DisplayService)
    end

    # In Shoes3, Shoes.setup installs gems. In Scarpe, this is a no-op stub
    # since gems are managed via Bundler. The block is simply yielded for compatibility.
    def setup(&block)
      block&.call
    end

    # Debug print method from Shoes3 — prints to stdout with ">> " prefix.
    # Useful for debugging within Shoes apps.
    #
    # @param object [Object] the object to print
    # @return [void]
    def p(object)
      puts ">> #{object.inspect}"
    end

    # Class-level url method for defining routes in Shoes subclasses
    # e.g., class Book < Shoes; url '/', :index; end
    def url(path, method_name)
      @class_routes ||= {}
      if path.is_a?(String) && path.include?('(')
        # Convert string patterns like '/page/(\d+)' to regex
        regex = Regexp.new("^#{path.gsub(/\(.*?\)/, '(.*?)')}$")
        @class_routes[regex] = method_name
      else
        @class_routes[path] = method_name
      end
    end

    # Get the routes defined on this class
    def class_routes
      @class_routes ||= {}
    end

    # Creates a Shoes app with a new window. The block parameter is used to create
    # drawables and set up handlers. Arguments are passed to Shoes::App.new internally.
    #
    # @incompatibility In Shoes3, this method will return normally.
    #   In Scarpe, after the block is executed, the method will not return and Scarpe
    #   will retain control of execution until the window is closed and the app quits.
    #
    # The styles come as keywords, or as one Hash, the way Ruby 1.9 programs passed them
    # (Hackety Hack's turtle: Shoes.app opts), which Ruby 3 hands over as a positional
    # argument (ledger A10). Keywords given beside a Hash win.
    #
    # @example Simple one-button app
    #   Shoes.app(title: "Button!", width: 200, height: 200) do
    #     @p = para "Press it NOW!"
    #     button("clicky") { @p.replace("You pressed it! CELEBRATION!") }
    #   end
    #
    # @param styles [Hash] the styles below, as a Hash
    # @param title [String] The new app window title
    # @param width [Integer] The new app window width
    # @param height [Integer] The new app window height
    # @param resizable [Boolean] Whether the app window should be resizeable
    # @param features [Symbol,Array<Symbol>] Additional Shoes extensions requested by the app
    # @return [Shoes::App] the new app (manual 859, ledger A3)
    # @see Shoes::App#new
    def app(styles = {}, **keywords, &app_code_body)
      unless styles.is_a?(Hash)
        raise ArgumentError, "Shoes.app takes its styles as keywords or a Hash, not #{styles.inspect}"
      end

      open_app(**styles.transform_keys(&:to_sym), **keywords, &app_code_body)
    end

    private

    def open_app(
      title: Shoes::App::DEFAULT_TITLE,
      width: Shoes::App::DEFAULT_WIDTH,
      height: Shoes::App::DEFAULT_HEIGHT,
      resizable: true,
      features: [],
      margin: nil,
      owner: nil,
      **_extras,
      &app_code_body
    )
      f = [features].flatten # Make sure this is a list, not a single symbol
      app = Shoes::App.new(title:, width:, height:, resizable:, features: f, owner:, &app_code_body)

      # If there's a pending Shoes subclass (e.g., class Book < Shoes), use it
      if Shoes.pending_app_class
        subclass = Shoes.pending_app_class
        Shoes.pending_app_class = nil  # Clear it so it doesn't affect future apps

        # Include the subclass as a module to get its instance methods
        # This works because we're extending the singleton class
        methods_to_copy = subclass.instance_methods(false)

        methods_to_copy.each do |method_name|
          # Get source location and use eval to redefine - but that's fragile
          # Instead, let's use a delegation pattern with the app as context

          # Read the method's arity and create a proper wrapper
          um = subclass.instance_method(method_name)

          # Define a wrapper that will eval the original method body in app's context
          # This is a bit hacky but works: we store the subclass and call via instance_eval
          app.define_singleton_method(method_name) do |*args, &block|
            # Create a temporary subclass instance that delegates to app for Shoes methods
            temp = subclass.allocate
            temp.instance_variable_set(:@__shoes_app__, self)

            # Define method_missing on the temp to delegate Shoes DSL calls to the app
            temp.define_singleton_method(:method_missing) do |name, *a, **kw, &b|
              @__shoes_app__.send(name, *a, **kw, &b)
            end
            temp.define_singleton_method(:respond_to_missing?) { |*| true }

            # Call the original method on temp (which delegates DSL calls to app)
            temp.send(method_name, *args, &block)
          end
        end

        # Copy routes from the subclass to the app
        subclass.class_routes.each do |path, method_name|
          app.url(path, method_name)
        end
      end

      app.init
      app.run
      app
    end

    public

    # Load a Shoes app from a file. By default, this will load old-style Shoes apps
    # from a .rb file with all the appropriate libraries loaded. By setting one or
    # more loaders, a Lacci-based display library can accept new file formats as
    # well, not just raw Shoes .rb files.
    #
    # An error that stops the file loading reaches Shoes.on_error as "startup" first, then
    # goes on up as before.
    #
    # @param relative_path [String] The current-dir-relative path to the file
    # @param dir [String, nil] the directory to run in; the file's own by default
    # @return [void]
    # @see Shoes.add_file_loader
    def run_app(relative_path, dir: nil)
      path = File.expand_path relative_path
      file_dir = File.dirname(path)

      # Shoes assumes we're starting from the app code's path
      Dir.chdir(dir || file_dir)

      # Shoes3 adds the app directory to the load path so that
      # require 'app/boot' style calls work from the app's directory
      $LOAD_PATH.unshift(file_dir) unless $LOAD_PATH.include?(file_dir)

      loaded = false
      begin
        file_loaders.each do |loader|
          if loader.call(path)
            loaded = true
            break
          end
        end
      rescue StandardError, ScriptError, SystemStackError => e
        report_error(e, during: "startup", program: path)
        raise
      end
      raise "Could not find a file loader for #{path.inspect}!" unless loaded

      nil
    end

    # Hands every error a handler, a timer or the program's startup raises to the block, on
    # the event loop, as a Hash (Shoes::ErrorReport): "class", "message", "backtrace",
    # "path", "line" and "during". The error is still logged and the program keeps going,
    # as it does with no block. Each call adds a block. A Scarpe extension (ledger K9).
    #
    # @return [Proc] the block
    def on_error(&block)
      raise ArgumentError, "Shoes.on_error needs a block" unless block

      error_hooks << block
      block
    end

    # The blocks Shoes.on_error was given.
    def error_hooks
      @error_hooks ||= []
    end

    # Display services call this when a handler, a timer or a startup raises: the console
    # lists the error, and every Shoes.on_error block hears of it. A block that raises is
    # logged and the others still run.
    #
    # @param during [String] "startup", "handler", "timer" or "exit"
    # @param program [String, nil] the program's main file, for the report's path and line
    # @return [Hash] the report
    def report_error(error, during:, program: nil)
      err = Shoes::ErrorReport.from(error, during: during, program: program)
      Shoes::Console.report(err)
      error_hooks.each do |hook|
        hook.call(err)
      rescue StandardError, ScriptError => e
        said = "A Shoes.on_error block raised #{e.class}: #{e.message}"
        Shoes::Log.instance ? Shoes::Log.logger("Shoes").error(said) : warn(said)
      end
      err
    end

    # Starts the Shoes program in the file at path, and hands back a Shoes::Program to follow
    # it with. The native display runs it in a process of its own on the same Ruby and
    # Scarpe, so an endless loop in it freezes only it, and stop ends it; other displays run
    # it inside this process, with a warning (Shoes::Program::InProcess). A Scarpe extension
    # (ledger K10).
    #
    # @param path [String] the program's file
    # @param dir [String] the directory it runs in (its own, by default)
    # @param args [Array<String>] its ARGV
    # @return [Shoes::Program]
    def run_program(path, dir: nil, args: [])
      path = File.expand_path(path)
      raise Errno::ENOENT, path unless File.file?(path)

      dir = File.expand_path(dir || File.dirname(path))
      args = Array(args).map(&:to_s)
      service = Shoes::DisplayService.display_service
      return service.run_program(path, dir: dir, args: args) if service.respond_to?(:run_program)

      Shoes::Program::InProcess.run(path, dir: dir, args: args)
    end

    # Opens the Shoes console (Shoes::Console), which Alt-/ opens too (Cmd-/ on a Mac).
    #
    # @return [Shoes::App] its window
    def show_console
      Shoes::Console.show
    end
    alias_method :show_log, :show_console

    def default_file_loaders
      [
        # By default we will always try to load any file, regardless of extension, as a Shoes Ruby file.
        proc do |path|
          load path
          true
        end
      ]
    end

    def file_loaders
      @file_loaders ||= default_file_loaders
    end

    def add_file_loader(loader)
      file_loaders.prepend(loader)
    end

    def reset_file_loaders
      @file_loaders = default_file_loaders
    end

    def set_file_loaders(loaders)
      @file_loaders = loaders
    end

    # Quit the Shoes application. Destroys all running Shoes apps.
    # In Shoes3 this was the standard way to exit from a button callback.
    #
    # @return [void]
    def quit
      Shoes.APPS.each(&:destroy)
    end
    alias_method :exit, :quit

    # Opens the manual in a window of its own, as Shoes 3 did, at `section` when one is
    # named (ledger K7). It never opens a browser.
    def show_manual(section = nil)
      require_relative "shoes/manual"
      Shoes::Manual.show(section)
    end
  end

  Shoes.APPS ||= []
end
