# frozen_string_literal: true

require_relative "../test_helper"

class TestCalziniAlert < Minitest::Test
  def setup
    @calzini = CalziniRenderer.new
  end

  def test_alert_defaults
    assert_equal %{<div id="elt-1" style="position:fixed;top:0;left:0;width:100%;height:100%;} +
      %{overflow:auto;z-index:1;background:rgba(0,0,0,0.4);display:flex;align-items:center;} +
      %{justify-content:center">} +
      %{<div style="min-width:200px;min-height:50px;padding:10px;display:flex;background:#fefefe;} +
      %{flex-direction:column;justify-content:space-between;border-radius:9px"><div></div>} +
      %{<button onclick="handle('click')">OK</button></div></div>},
      @calzini.render("alert", {})
  end

  def test_alert_hidden
    # A hidden alert is display:none for the outer div
    assert_equal %{<div id="elt-1" style="position:fixed;top:0;left:0;width:100%;height:100%;} +
      %{overflow:auto;z-index:1;background:rgba(0,0,0,0.4);display:none;align-items:center;} +
      %{justify-content:center">} +
      %{<div style="min-width:200px;min-height:50px;padding:10px;display:flex;background:#fefefe;} +
      %{flex-direction:column;justify-content:space-between;border-radius:9px"><div></div>} +
      %{<button onclick="handle('click')">OK</button></div></div>},
      @calzini.render("alert", { "hidden" => true })
  end
end
