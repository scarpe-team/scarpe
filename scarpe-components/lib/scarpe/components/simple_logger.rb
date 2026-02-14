# frozen_string_literal: true

# SimpleLogImpl - A minimal logger implementation to replace the 'logging' gem (256KB savings)
# API-compatible with ModularLogImpl but uses Ruby's stdlib Logger

require "logger"
require "json"
require "shoes/log"

module Scarpe
  module Components
    class SimpleLogImpl
      include Shoes::Log # for constants

      LEVELS = {
        "debug" => Logger::DEBUG,
        "info" => Logger::INFO,
        "warn" => Logger::WARN,
        "error" => Logger::ERROR,
        "err" => Logger::ERROR,
        "fatal" => Logger::FATAL,
      }.freeze

      def initialize
        @loggers = {}
        @default_level = Logger::INFO
        @appenders = [$stdout]
        @pattern = "[%<time>.8s] %-5<level>s %<name>s: %<message>s"
      end

      def logger_for_component(component)
        @loggers[component] ||= create_logger(component)
      end

      def configure_logger(log_config)
        return if log_config.nil?

        if log_config.is_a?(String) && File.exist?(log_config)
          log_config = JSON.load_file(log_config)
        end

        # Handle default component
        if log_config[DEFAULT_COMPONENT]
          configure_default(log_config[DEFAULT_COMPONENT])
        end

        # Configure specific loggers
        log_config.each do |component, config|
          next if component == DEFAULT_COMPONENT
          configure_component_logger(component, config)
        end
      end

      private

      def create_logger(name)
        SimpleComponentLogger.new(name, @default_level, @appenders, @pattern)
      end

      def configure_default(config)
        case config
        when String
          @default_level = LEVELS[config] || Logger::INFO
        when Array
          level, *locations = config
          @default_level = LEVELS[level] || Logger::INFO
          @appenders = locations.map { |loc| location_to_io(loc) }
        end
      end

      def configure_component_logger(component, config)
        logger = logger_for_component(component)
        case config
        when String
          logger.level = LEVELS[config] || Logger::INFO
        when Array
          level, *locations = config
          logger.level = LEVELS[level] || Logger::INFO
          logger.appenders = locations.map { |loc| location_to_io(loc) }
        end
      end

      def location_to_io(location)
        case location.to_s.downcase
        when "stdout"
          $stdout
        when "stderr"
          $stderr
        else
          File.open(location, "a")
        end
      end
    end

    # Minimal logger that mimics the Logging gem's logger interface
    class SimpleComponentLogger
      attr_accessor :level, :appenders

      LEVEL_NAMES = %w[DEBUG INFO WARN ERROR FATAL].freeze

      def initialize(name, level, appenders, pattern)
        @name = name
        @level = level
        @appenders = appenders
        @pattern = pattern
        @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def debug(msg = nil, &block)
        log(Logger::DEBUG, msg, &block)
      end

      def info(msg = nil, &block)
        log(Logger::INFO, msg, &block)
      end

      def warn(msg = nil, &block)
        log(Logger::WARN, msg, &block)
      end

      def error(msg = nil, &block)
        log(Logger::ERROR, msg, &block)
      end

      def fatal(msg = nil, &block)
        log(Logger::FATAL, msg, &block)
      end

      def debug?
        @level <= Logger::DEBUG
      end

      def info?
        @level <= Logger::INFO
      end

      def warn?
        @level <= Logger::WARN
      end

      def error?
        @level <= Logger::ERROR
      end

      def fatal?
        @level <= Logger::FATAL
      end

      private

      def log(level, msg = nil, &block)
        return unless level >= @level

        msg = block.call if block && msg.nil?
        return if msg.nil?

        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time
        formatted = format(
          @pattern,
          time: format("%.3f", elapsed),
          level: LEVEL_NAMES[level],
          name: @name,
          message: msg
        )

        @appenders.each do |io|
          io.puts(formatted)
          io.flush if io.respond_to?(:flush)
        end
      end
    end
  end
end
