# frozen_string_literal: true

# We're separating Shoes from Scarpe, a little at a time. This should be requirable
# without using Scarpe at all.
#
# The Lacci gem is like the old Shoes-core from Shoes4: a way
# to handle the DSL and command-line parts of Shoes without knowing anything about how the
# display side works at all.

if RUBY_VERSION[0..2] < "3.2"
  Shoes::Log.logger("Shoes").error("Lacci (Scarpe, Shoes) requires Ruby 3.2 or higher!")
  exit(-1)
end

class Shoes; end
class Shoes::Error < StandardError; end
require_relative "shoes/errors"

require_relative "shoes/constants"

# Shoes adds some top-level methods and constants that can be used everywhere. Kernel is where they go.
module Kernel
  include Shoes::Constants
end

require_relative "shoes/display_service"

# Pre-declare classes that get referenced outside their own require file
class Shoes::Drawable < Shoes::Linkable; end
class Shoes::Slot < Shoes::Drawable; end
class Shoes::Widget < Shoes::Slot; end

require_relative "shoes/log"
require_relative "shoes/colors"

require_relative "shoes/builtins"

require_relative "shoes/background"
require_relative "shoes/border"
require_relative "shoes/spacing"

require_relative "shoes/drawable"
require_relative "shoes/app"
require_relative "shoes/drawables"

require_relative "shoes/download"

if ENV["SHOES_SPEC_TEST"]
  require_relative "shoes-spec"
end

# The module containing Shoes in all its glory.
# Shoes is a platform-independent GUI library, designed to create
# small visual applications in Ruby.
#
class Shoes
  include Shoes::Constants # Doesn't the Kernel include handle this?

  class << self
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
    # @return [void]
    # @see Shoes::App#new
    def app(
      title: "Shoes!",
      width: 480,
      height: 420,
      resizable: true,
      &app_code_body
    )
      app = Shoes::App.new(title:, width:, height:, resizable:, &app_code_body)
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
        end,
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
  end
end
