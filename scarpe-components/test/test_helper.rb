# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "shoes"

require "minitest/autorun"

require "minitest/reporters"
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

# For tests, default to simple print logger
# TODO: switch to modular logger and failure-logged tests?
require "shoes/log"
require "scarpe/components/print_logger"
Shoes::Log.instance = Scarpe::Components::PrintLogImpl.new
Shoes::Log.configure_logger(Shoes::Log::DEFAULT_LOG_CONFIG)

require "scarpe/components/unit_test_helpers"

require "scarpe/components/calzini"

class CalziniRenderer
  include Scarpe::Components::Calzini

  attr_accessor :html_id

  def initialize
    @html_id = "elt-1"
  end

  def handler_js_code(event, *args)
    js_args = ["'#{event}'", *args].join(", ")
    "handle(#{js_args})"
  end
end

class Minitest::Test
  include Scarpe::Test::Helpers
end
