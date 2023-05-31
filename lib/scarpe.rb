# frozen_string_literal: true

require_relative "scarpe/logger"

# This will never be triggered -- we use the (...) feature below, which means this
# file won't even parse in old Rubies.
if RUBY_VERSION[0..2] < "3.2"
  Scarpe::Logger.logger("Scarpe").error("Scarpe requires Ruby 3.2 or higher!")
  exit(-1)
end

require "securerandom"
require "json"

require_relative "scarpe/version"
require_relative "scarpe/promises"
require_relative "scarpe/display_service"
require_relative "scarpe/widgets"

# Display services
require_relative "scarpe/wv"
require_relative "scarpe/glibui" if ENV["SCARPE_DISPLAY_SERVICES"]&.include?("Scarpe::GlimmerLibUIDisplayService")

class Scarpe
  class << self
    def app(...)
      app = Scarpe::App.new(...)
      app.init
      app.run
      app.destroy
    end
  end
end
