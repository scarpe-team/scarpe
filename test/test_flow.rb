# frozen_string_literal: true

require "test_helper"

class TestWebviewFlow < ScarpeWebviewTest
  def test_it_accepts_a_height
    flow = Scarpe::Webview::Flow.new("width" => 7, "height" => 25, "margin" => 4, "padding" => 5, "shoes_linkable_id" => 1) do
      "fishes that flop"
    end

    assert(flow.to_html.include?("height:25px"))
  end
end
