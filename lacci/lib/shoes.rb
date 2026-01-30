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
require_relative 'shoes/colors'

require_relative 'shoes/builtins'

require_relative 'shoes/background'

require_relative 'shoes/drawable'
require_relative 'shoes/app'
require_relative 'shoes/drawables'

require_relative 'shoes/download'

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
    # @incompatibility In Shoes3 the parameters were a hash of options, not keyword arguments.
    #
    # @example Simple one-button app
    #   Shoes.app(title: "Button!", width: 200, height: 200) do
    #     @p = para "Press it NOW!"
    #     button("clicky") { @p.replace("You pressed it! CELEBRATION!") }
    #   end
    #
    # @param title [String] The new app window title
    # @param width [Integer] The new app window width
    # @param height [Integer] The new app window height
    # @param resizable [Boolean] Whether the app window should be resizeable
    # @param features [Symbol,Array<Symbol>] Additional Shoes extensions requested by the app
    # @return [void]
    # @see Shoes::App#new
    def app(
      title: 'Shoes!',
      width: 480,
      height: 420,
      resizable: true,
      features: [],
      &app_code_body
    )
      f = [features].flatten # Make sure this is a list, not a single symbol
      app = Shoes::App.new(title:, width:, height:, resizable:, features: f, &app_code_body)

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
      nil
    end

    # Load a Shoes app from a file. By default, this will load old-style Shoes apps
    # from a .rb file with all the appropriate libraries loaded. By setting one or
    # more loaders, a Lacci-based display library can accept new file formats as
    # well, not just raw Shoes .rb files.
    #
    # @param relative_path [String] The current-dir-relative path to the file
    # @return [void]
    # @see Shoes.add_file_loader
    def run_app(relative_path)
      path = File.expand_path relative_path
      dir = File.dirname(path)

      # Shoes assumes we're starting from the app code's path
      Dir.chdir(dir)

      loaded = false
      file_loaders.each do |loader|
        if loader.call(path)
          loaded = true
          break
        end
      end
      raise "Could not find a file loader for #{path.inspect}!" unless loaded

      nil
    end

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
  end

  Shoes.APPS ||= []
end
