# frozen_string_literal: true

require "logging"
require "json"

require "shoes/log"

# Requires the logging gem

class Scarpe; end
module Scarpe::Components; end
class Scarpe
  class Components::ModularLogImpl
    include Shoes::Log # for constants

    def logger_for_component(component)
      Logging.logger[component]
    end

    private

    def name_to_severity(data)
      case data
      when "debug"
        :debug
      when "info"
        :info
      when "warn"
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
        Logging.appenders.stdout layout: @custom_log_layout
      when "stderr"
        Logging.appenders.stderr layout: @custom_log_layout
      when String
        Logging.appenders.file data, layout: @custom_log_layout
      else
        raise "Don't know how to convert #{data.inspect} to an appender!"
      end
    end

    def json_configure_logger(logger, data)
      case data
      in String
        sev = name_to_severity(data)
        logger.level = sev
      in [level, *locations]
        if logger.name != "root"
          # The Logging gem doesn't have an additive property on the root logger
          logger.additive = false # Don't also log to parent/root loggers
        end

        logger.appenders = locations.map { |where| json_to_appender(where) }

        logger.level = name_to_severity(level)
      else
        raise "Don't know how to use #{data.inspect} to specify a logger!"
      end
    end

    def freeze_log_config(log_config)
      log_config.each do |k, v|
        k.freeze
        v.freeze
        v.each(&:freeze) if v.is_a?(Array)
      end
      log_config.freeze
    end

    public

    def configure_logger(log_config)
      # TODO: custom coloring? https://github.com/TwP/logging/blob/master/examples/colorization.rb
      @custom_log_layout = Logging.layouts.pattern pattern: '[%r] %-5l %c: %m\n'

      if log_config.is_a?(String) && File.exist?(log_config)
        log_config = JSON.load_file(log_config)
      end

      log_config = freeze_log_config(log_config) unless log_config.nil?
      @current_log_config = log_config # Save a copy for later

      Logging.reset # Reset all Logging settings to defaults
      Logging.reopen # For log-reconfig (e.g. test failures), often important to *not* store an open handle to a moved file
      return if log_config.nil?

      Logging.logger.root.appenders = [Logging.appenders.stdout]

      default_logger = log_config[DEFAULT_COMPONENT] || "info"
      json_configure_logger(Logging.logger.root, default_logger)

      log_config.each do |component, logger_data|
        next if component == DEFAULT_COMPONENT

        sublogger = Logging.logger[component]
        json_configure_logger(sublogger, logger_data)
      end
    end
  end
end

#Shoes::Log.instance = Scarpe::PrintLogImpl.new
#Shoes::Log.configure_logger(Shoes::Log::DEFAULT_LOG_CONFIG)
