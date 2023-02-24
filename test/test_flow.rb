# frozen_string_literal: true

require "test_helper"

# Going to need to rewrite this, or at a minimum heavily modify it :-(
__END__

class TestFlow < Minitest::Test
  def test_it_accepts_a_height
    flow = Scarpe::Flow.new(height: 25) do
      "fishes that flop"
    end

    assert(flow.to_html.include?("height:25px"))
  end
end
