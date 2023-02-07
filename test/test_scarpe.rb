# frozen_string_literal: true

require "test_helper"

class TestScarpe < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Scarpe::VERSION
  end

  def test_hello_world_app
    test_scarpe_app <<SCARPE_APP
  para "Hello World"
  js_eval "scarpeStatusAndExit(true);"
SCARPE_APP
  end
end
