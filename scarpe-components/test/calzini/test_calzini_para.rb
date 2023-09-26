# frozen_string_literal: true

require_relative "../test_helper"

class TestCalziniPara < Minitest::Test
  def setup
    @calzini = CalziniRenderer.new
  end

  # Note that Calzini doesn't render the text items for itself.
  def test_para_simple
    assert_equal %{<p id="elt-1">OK</p>},
      @calzini.render("para", {}) { "OK" }
  end

  def test_para_with_stroke_and_font
    assert_equal %{<p id="elt-1" style="color:#FF0000;font-family:Lucida">OK</p>},
      @calzini.render("para", { "stroke" => [1.0, 0.0, 0.0], "font" => "Lucida" }) { "OK" }
  end

  def test_para_with_string_banner
    assert_equal %{<p id="elt-1" style="font-size:48px"></p>},
      @calzini.render("para", { "size" => "banner" })
  end

  def test_para_with_symbol_banner
    assert_equal %{<p id="elt-1" style="font-size:48px"></p>},
      @calzini.render("para", { "size" => :banner })
  end

  # Eventually this should probably need to be marked as a Scarpe extension, here or
  # elsewhere.
  def test_para_with_html_attributes
    assert_equal %{<p avocado="true" class="avocado_bearing" id="elt-1"></p>},
      @calzini.render("para", { "html_attributes" => { "avocado" => true, "class" => "avocado_bearing" } })
  end
end
