# frozen_string_literal: true

require "shoes/log"
require "json"

module Niente; end
class Niente::LogImpl
  include Shoes::Log # for constants

  class PrintLogger
    def initialize(_)
    end

    [:error, :warn, :debug, :info].each do |level|
      define_method(level) do |msg|
        puts "#{level}: #{msg}"
      end
    end
  end

  def logger_for_component(component)
    PrintLogger.new(component.to_s)
  end

  def configure_logger(log_config)
  end
end

#Shoes::Log.instance = Niente::LogImpl.new
