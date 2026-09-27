# frozen_string_literal: true

# A Shoes::Log implementation that writes to stderr, so stdout stays the app's own.
# Level: SCARPE_NATIVE_LOG_LEVEL (debug info warn error), else debug under SCARPE_DEBUG, else warn.
class Scarpe::Native::LogImpl
  LEVELS = { "debug" => 0, "info" => 1, "warn" => 2, "error" => 3, "fatal" => 4 }.freeze

  class Logger
    def initialize(component, impl)
      @component = component
      @impl = impl
    end

    LEVELS.each_key do |level|
      define_method(level) { |msg| @impl.write(level, @component, msg) }
    end
  end

  attr_reader :level

  def initialize
    @level = LEVELS.fetch(ENV["SCARPE_NATIVE_LOG_LEVEL"].to_s.downcase) { ENV["SCARPE_DEBUG"] ? 0 : 2 }
  end

  def logger_for_component(component)
    Logger.new(component.to_s, self)
  end

  # Levels come from the environment; Lacci's default config would turn on info noise.
  def configure_logger(_log_config)
  end

  def write(level, component, msg)
    $stderr.puts("[scarpe-native] #{component} #{level}: #{msg}") if LEVELS[level] >= @level
  end
end
