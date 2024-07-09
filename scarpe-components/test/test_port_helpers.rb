# frozen_string_literal: true

require_relative "test_helper"

require "scarpe/components/port_helpers"
class TestPortHelpers < Minitest::Test
  include Scarpe::Components::PortHelpers

  def test_port_finder
    assert_equal false, port_working?("127.0.0.1", 9832), "Port 9832 should be unused!"
  end
end
