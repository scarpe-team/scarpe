# frozen_string_literal: true

require "test_helper"

class TestStack < Minitest::Test
  def test_it_accepts_a_height
    stack = Scarpe::Stack.new(height: 25) do
      "fishes that flop"
    end

    assert(stack.to_html.include?("height:25px"))
  end
end
