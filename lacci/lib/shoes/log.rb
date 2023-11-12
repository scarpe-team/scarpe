# frozen_string_literal: true

# Old-style Shoes logging is really simple. We need more logging for our
# framework, so we add a not-included-in-old-Shoes module for it. This adds
# the *possibility* of logging, but Scarpe includes a much more
# comprehensive solution that plugs into this one.

# If used alone, this will fail because the @instance is nil. It needs
# an implementation to be plugged in.

class Shoes
  LOG_LEVELS = [:debug, :info, :warn, :error, :fatal].freeze

  # Include this module to get a @log instance variable to log as your
  # configured component.
  module Log
    # These constants will wind up included in a lot of places. Should they move?
    DEFAULT_COMPONENT = "default"
    DEFAULT_LOG_CONFIG = {
      "default" => "info",
    }
    DEFAULT_DEBUG_LOG_CONFIG = {
      "default" => "debug",
    }

    class << self
      attr_reader :instance
      attr_reader :current_log_config

      def instance=(impl_object)
        raise(Shoes::TooManyInstancesError, "Already have an instance for Shoes::Log!") if @instance

        @instance = impl_object
      end

      def logger(component = self)
        @instance.logger_for_component(component)
      end

      def configure_logger(log_config)
        @instance.configure_logger(log_config)
      end
    end

    def log_init(component = self)
      @log = Shoes::Log.instance.logger_for_component(component)
    end
  end

  class LoggedWrapper
    include ::Shoes::Log
    def initialize(instance, component = instance)
      log_init(component)

      @instance = instance
    end

    def method_missing(method, ...)
      self.singleton_class.define_method(method) do |*args, **kwargs, &block|
        ret = @instance.send(method, *args, **kwargs, &block)
        @log.info("Method: #{method} Args: #{args.inspect} KWargs: #{kwargs.inspect} Block: #{block ? "y" : "n"} Return: #{ret.inspect}")
        ret
      end
      send(method, ...)
    end

    def respond_to_missing?(method_name, include_private = false)
      @instance.respond_to_missing?(method_name, include_private)
    end
  end
end
