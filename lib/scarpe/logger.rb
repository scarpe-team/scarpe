# frozen_string_literal: true

require "logger"

class Scarpe
  class Logger
    class << self
      attr_accessor :logger
    end

    def self.initialize_logger
      @logger ||= ::Logger.new($stdout)
      @logger.level = ::Logger::INFO

      @logger.formatter = proc do |severity, _datetime, _progname, message|
        "#{severity} #{message}\n"
      end
    end
  end
end

Scarpe::Logger.initialize_logger
