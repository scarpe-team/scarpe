# frozen_string_literal: true

# A Shoes::Log implementation that writes to stderr, so stdout stays the app's own, and lists
# every line it writes in the Shoes console (Shoes::Console) too.
# Level: SCARPE_NATIVE_LOG_LEVEL (debug info warn error), else debug under SCARPE_DEBUG, else warn.
class Scarpe::Native::LogImpl
  LEVELS = { "debug" => 0, "info" => 1, "warn" => 2, "error" => 3, "fatal" => 4 }.freeze

  class Logger
    def initialize(component, impl)
      @component = component
      @impl = impl
    end

    # console: false keeps a line out of the Shoes console, for one it lists another way.
    LEVELS.each_key do |level|
      define_method(level) { |msg, console: true| @impl.write(level, @component, msg, console: console) }
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

  def write(level, component, msg, console: true)
    return unless LEVELS[level] >= @level

    Scarpe::Native.diagnostics.puts("[scarpe-native] #{component} #{level}: #{msg}")
    Shoes::Console.log(level, "#{component}: #{msg}") if console && defined?(Shoes::Console)
  end
end

module Scarpe::Native
  # Where Scarpe's own lines go: stderr, or in a program Shoes.run_program started, the
  # stderr it was given rather than the program's own output, which goes to the parent
  # (ProgramChild).
  def self.diagnostics
    @diagnostics || $stderr
  end

  def self.diagnostics=(io)
    @diagnostics = io
  end
end
