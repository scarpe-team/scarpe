# frozen_string_literal: true

require_relative "../test_helper"

class TestCalziniPara < Minitest::Test
  def setup
    @calzini = CalziniRenderer.new
  end

  def test_para_simple
    assert_equal %{<p id="elt-1">OK</p>},
      @calzini.render("para", {}) { "OK" }
  end

  def test_para_with_align
    assert_equal %{<div id=\"elt-1\" style=\"text-align:right;width:100%\"><p>OK</p></div>},
      @calzini.render("para", { "align" => "right" }) { "OK" }
  end

  def test_para_with_stroke_and_font
    assert_equal %{<p id="elt-1" style="color:#FF0000;font-family:Lucida">OK</p>},
      @calzini.render("para", { "stroke" => [1.0, 0.0, 0.0], "family" => "Lucida" }) { "OK" }
  end

  def test_para_with_string_banner
    assert_equal %{<p id="elt-1" style="font-size:48px"></p>},
      @calzini.render("para", { "size" => "banner" })
  end

  def test_para_with_symbol_banner
    assert_equal %{<p id="elt-1" style="font-size:48px"></p>},
      @calzini.render("para", { "size" => :banner })
  end
end
