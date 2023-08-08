# frozen_string_literal: true

require "shoes/log"
require "json"

class Scarpe::PrintLogImpl
  include Shoes::Log # for constants

  class PrintLogger
    def initialize(component_name)
      @comp_name = component_name
    end

    def error(msg)
      puts "#{@comp_name} error: #{msg}"
    end

    def warn(msg)
      puts "#{@comp_name} warn: #{msg}"
    end

    def debug(msg)
      puts "#{@comp_name} debug: #{msg}"
    end

    def info(msg)
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
