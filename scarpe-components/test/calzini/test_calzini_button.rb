# frozen_string_literal: true

require_relative "../test_helper"

class TestCalziniButton < Minitest::Test
  def setup
    @calzini = CalziniRenderer.new
  end

  def test_button_defaults
    assert_equal %{<button id="elt-1" onclick="handle('click')"></button>}, @calzini.render("button", {})
  end

  def test_button_all_properties_set
    props = {
      "color" => "red",
      "padding_top" => "4",
      "padding_bottom" => "5",
      "text_color" => "blue",
      "width" => 201,
      "height" => 203,
      "font_size" => "14",
      "top" => "10",
      "left" => "11",
      "size" => "17",
      "font" => "Lucida",
    }
    assert_equal %{<button id="elt-1" onclick="handle('click')" } +
      %{style="background-color:red;padding-top:4;padding-bottom:5;color:blue;} +
      %{width:201px;height:203px;font-size:17px;top:10;left:11;position:absolute;} +
      %{font-family:Lucida"></button>},
      @calzini.render("button", props)
  end

  def test_button_all_properties_nil
    props = {
      "color" => nil,
      "padding_top" => nil,
      "padding_bottom" => nil,
      "text_color" => nil,
      "width" => nil,
      "height" => nil,
      "font_size" => nil,
      "top" => nil,
      "left" => nil,
      "size" => nil,
      "font" => nil,
      "stroke" => nil,
    }
    assert_equal %{<button id="elt-1" onclick="handle('click')"></button>}, @calzini.render("button", props)
  end
end
