# frozen_string_literal: true

require_relative "scarpe/logger"

if RUBY_VERSION[0..2] < "3.2"
  Scarpe::Logger.logger.error("Scarpe requires Ruby 3.2 or higher!")
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
require_relative "scarpe/glibui" if ENV["SCARPE_DISPLAY_SERVICES"] == "Scarpe::GlimmerLibUIDisplayService"

class Scarpe
  class << self
    def error(message)
      Scarpe::Logger.logger.error(message)
    end

    def warn(message)
      Scarpe::Logger.logger.warn(message)
    end

    def info(message)
      Scarpe::Logger.logger.info(message)
    end

    def debug(message)
      Scarpe::Logger.logger.debug(message)
    end

    def app(...)
      app = Scarpe::App.new(...)
      app.init
      app.run
      app.destroy
    end
  end
end
