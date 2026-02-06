# frozen_string_literal: true

require "shoes/log"
require "json"

module Scarpe; end
module Scarpe::Components; end
class Scarpe::Components::PrintLogImpl
  include Shoes::Log # for constants

  class PrintLogger
    class << self
      attr_accessor :silence
      attr_accessor :min_level
    end

    LEVELS = {
      :never => 1000,
      :error => 4,
      :warn => 3,
      :info => 2,
      :debug => 1,
      :always => -1,
    }
    PrintLogger.min_level = LEVELS[:always]

    def initialize(component_name)
      @comp_name = component_name
    end

    def error(msg)
      return if PrintLogger.silence || PrintLogger.min_level > LEVELS[:error]
      puts "#{@comp_name} error: #{msg}"
    end

    def warn(msg)
      return if PrintLogger.silence || PrintLogger.min_level > LEVELS[:warn]
      puts "#{@comp_name} warn: #{msg}" unless PrintLogger.silence
    end

    def debug(msg)
      return if PrintLogger.silence || PrintLogger.min_level > LEVELS[:debug]
      puts "#{@comp_name} debug: #{msg}" unless PrintLogger.silence
    end

    def info(msg)
      return if PrintLogger.silence || PrintLogger.min_level > LEVELS[:info]
      puts "#{@comp_name} info: #{msg}"
    end
  end

  def logger_for_component(component)
    PrintLogger.new(component.to_s)
  end

  def configure_logger(log_config)
    # For now, ignore
  end
end

#Shoes::Log.instance = Scarpe::PrintLogImpl.new
#Shoes::Log.configure_logger(Shoes::Log::DEFAULT_LOG_CONFIG)
