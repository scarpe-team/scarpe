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

d_s = ENV["SCARPE_DISPLAY_SERVICE"] || "wv_local"
# This is require, not require_relative, to allow gems to supply a new display service
require "scarpe/#{d_s}"

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
