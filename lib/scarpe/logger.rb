# frozen_string_literal: true

require "logging"
require "json"

class Scarpe
  LOG_LEVELS = [:debug, :info, :warning, :error, :fatal].freeze

  # Include this module to get a @log instance variable to log as your
  # configured component.
  module Log
    DEFAULT_LOG_CONFIG = {
      "default": "info",
    }

    def log_init(component = self)
      @log = Logging.logger[component]
    end
  end

  class Logger
    class << self
      def logger(component = self)
        Logging.logger[component]
      end

      def name_to_severity(data)
        case data
        when "debug"
          :debug
        when "info"
          :info
        when "warn", "warning"
          :warn
        when "err", "error"
          :error
        when "fatal"
          :fatal
        else
          raise "Don't know how to treat #{data.inspect} as a logger severity!"
        end
      end

      def json_to_appender(data)
        case data.downcase
        when "stdout"
          Logging.appenders.stdout
        when "stderr"
          Logging.appenders.stderr
        when String
          Logging.appenders.file(data)
        else
          raise "Don't know how to convert #{data.inspect} to an appender!"
        end
      end

      def json_configure_logger(logger, data)
        case data
        in String
          sev = name_to_severity(data)
          logger.level = sev
        in [where, level]
          app = json_to_appender(where)
          logger.appenders = [app]
          logger.additive = false # Don't also log to parent/root loggers
          logger.level = name_to_severity(level)
        else
          raise "Don't know how to use #{data.inspect} to specify a logger!"
        end
      end

      # To provide initial logger configuration - called from this file
      def initialize_logger(log_config)
        Logging.logger.root.appenders = [Logging.appenders.stdout]

        default_logger = log_config.delete("default") || "info"
        json_configure_logger(Logging.logger.root, default_logger)

        log_config.each do |component, logger_data|
          sublogger = Logging.logger[component]
          json_configure_logger(sublogger, logger_data)
        end
      end
    end
  end

  class LoggedWrapper
    include ::Scarpe::Log
    def initialize(instance, component = instance)
      log_init(component)

      @instance = instance
    end

    def method_missing(method, ...)
      self.singleton_class.define_method(method) do |*args, **kwargs, &block|
        @log.info("Method: #{method} Args: #{args.inspect} KWargs: #{kwargs.inspect} Block: #{block ? "y" : "n"}")
        @instance.send(method, *args, **kwargs, &block)
      end
      send(method, ...)
    end
  end
end

log_config = ENV["SCARPE_LOG_CONFIG"] ? JSON.load_file(ENV["SCARPE_LOG_CONFIG"]) : Scarpe::Log::DEFAULT_LOG_CONFIG

Scarpe::Logger.initialize_logger(log_config)
