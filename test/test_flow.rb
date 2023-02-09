# frozen_string_literal: true

require "test_helper"

class TestFlow < Minitest::Test
  def test_it_accepts_a_height
    flow = Scarpe::Flow.new(width: "10px", height: "25px") do
      "fishes that flop"
    end

    assert(flow.to_html.include?("height:25px"))
  end
end
