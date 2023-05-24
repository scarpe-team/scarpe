# frozen_string_literal: true

require "logging"
require "json"

class Scarpe
  LOG_LEVELS = [:debug, :info, :warning, :error, :fatal].freeze

  module Log
    def log_init(component = nil)
      @log = Logging.logger[component || self]
    end
  end

  class Logger
    class << self
      # Default overall level
      attr_accessor :level

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
        if data.is_a?(String)
          case data.downcase
          when "stdout"
            Logging.appenders.stdout
          when "stderr"
            Logging.appenders.stderr
          else
            Logging.appenders.file(data)
          end
        end
      end

      def json_configure_logger(logger, data)
        if data.is_a?(String)
          sev = name_to_severity(data)
          logger.level = sev
          return
        end

        if data.is_a?(Array) && data.size == 2
          where, level = *data
          app = json_to_appender(where)
          logger.appenders = [app]
          logger.additive = false # Don't also log to parent/root loggers
          logger.level = name_to_severity(level)
          return
        end

        raise "Don't know how to use #{data.inspect} to specify a logger!"
      end

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
end

log_config = if ENV["SCARPE_LOG_CONFIG"]
  JSON.parse(File.read(ENV["SCARPE_LOG_CONFIG"]))
else
  {
    "default": "info",
  }
end

Scarpe::Logger.initialize_logger(log_config)
