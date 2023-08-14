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

module Shoes; end
class Shoes::Error < StandardError; end

require_relative "shoes/constants"
module Kernel
  include Shoes::Constants
end

require_relative "shoes/log"
require_relative "shoes/display_service"
require_relative "shoes/colors"

require_relative "shoes/background"
require_relative "shoes/border"
require_relative "shoes/spacing"

require_relative "shoes/widget"
require_relative "shoes/app"
require_relative "shoes/widgets"

require_relative "shoes/download"

# The module containing Shoes in all its glory.
# Shoes is a platform-independent GUI library, designed to create
# small visual applications in Ruby.
#
module Shoes
  class << self
    # Creates a Shoes app with a new window. The block parameter is used to create
    # widgets and set up handlers. Arguments are passed to Shoes::App.new internally.
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
  end
end
