# frozen_string_literal: true

require_relative "../test_helper"

class TestCalziniArtDrawables < Minitest::Test
  def setup
    @calzini = CalziniRenderer.new
  end

  def assert_start_and_finish(start, finish, value)
    assert value.start_with?(start),
      "Expected string to start with correct prefix... prefix: #{start.inspect} Value: #{value.inspect}"
    assert value.end_with?(finish),
      "Expected string to end with correct suffix... suffix: #{finish.inspect} Value: #{value.inspect}"
  end

  def test_arc_example
    arc_example = @calzini.render(
      "arc",
      {
        "width" => 200,
        "height" => 150,
        "left" => 17,
        "top" => 42,
        "angle1" => 3.14 / 2,
        "angle2" => 3.14 / 4,
      },
    )
    ex_html_start = %{<div id="elt-1" style="position:absolute;top:42px;left:17px;width:200px;height:150px"><svg width="200" height="150"><path d="M100 75 L200 75 A100 75 0 1 0 170.73882691671997 128.01188858290243 Z" transform="rotate(, 100, 75)" /></svg></div>}
    ex_html_end = %{" /></svg></div>}
    assert_start_and_finish(ex_html_start, ex_html_end, arc_example)
  end

  def test_line_example
    assert_equal %{<div id="elt-1" style="position:absolute;top:4px;left:7px">} +
      %{<svg width="100" height="104"><line x1="7" y1="4" x2="100" y2="104" style="stroke:black;stroke-width:4">} +
      %{</line></svg></div>},
      @calzini.render("line", { "top" => "4", "left" => "7", "x1" => "20", "y1" => "17", "x2" => "100", "y2" => "104" })
  end

  def test_line_draw_context
    assert_equal %{<div id="elt-1" style="position:absolute;top:4px;left:7px">} +
      %{<svg width="100" height="104"><line x1="7" y1="4" x2="100" y2="104" style="stroke:red;stroke-width:4">} +
      %{</line></svg></div>},
      @calzini.render(
        "line",
        { "top" => "4", "left" => "7", "x1" => "20", "y1" => "17", "x2" => "100", "y2" => "104", "draw_context" => { "stroke" => "red" } },
      )
  end

  def test_line_hidden
    assert_equal %{<div id="elt-1" style="display:none;position:absolute;top:4px;left:7px">} +
      %{<svg width="100" height="104"><line x1="7" y1="4" x2="100" y2="104" style="stroke:black;stroke-width:4">} +
      %{</line></svg></div>},
      @calzini.render("line", { "top" => "4", "left" => "7", "x1" => "20", "y1" => "17", "x2" => "100", "y2" => "104", "hidden" => true })
  end

  def test_rect_default_stroke
    assert_equal %{<div id="elt-1" style="display:none;position:absolute;top:9;left:12;width:147;height:91">} +
      %{<svg width="147" height="91"><rect x="12" y="9" width="147" height="91" transform="rotate( 73 45)" />} +
      %{</svg></div>},
      @calzini.render("rect", { "top" => "9", "left" => "12", "width" => "147", "height" => "91", "draw_context" => {}, "hidden" => true })
  end

  def test_rect_round_corners
    assert_equal %{<div id="elt-1" style="display:none;position:absolute;top:9;left:12;width:147;height:91">} +
      %{<svg width="177" height="121"><rect x="12" y="9" width="147" height="91" style="stroke:red" rx="15" transform="rotate( 88 60)" />} +
      %{</svg></div>},
      @calzini.render(
        "rect",
        {
          "top" => "9",
          "left" => "12",
          "width" => "147",
          "height" => "91",
          "curve" => "15",
          "draw_context" => { "stroke" => "red" },
          "hidden" => true,
        },
      )
  end

  def test_rect_hidden
    assert_equal %{<div id="elt-1" style="display:none;position:absolute;top:4;left:7;width:20;height:17">} +
      %{<svg width="20" height="17"><rect x="7" y="4" width="20" height="17" transform="rotate( 10 8)" />} +
      %{</svg></div>},
      @calzini.render("rect", { "top" => "4", "left" => "7", "width" => "20", "height" => "17", "hidden" => true })
  end

  def test_star_simple
    start = %{<div id="elt-1"><svg width="2.0" height="2.0"><polygon points="2.0,1.0,1.4}
    finish = %{" style="fill:black;stroke:black;stroke-width:2" /></svg></div>}
    assert_start_and_finish start,
      finish,
      @calzini.render("star", { "points" => 5, "outer" => 2.0, "inner" => 1.0 })
  end

  def test_star_colors
    start = %{<div id="elt-1"><svg width="2.0" height="2.0"><polygon points="2.0,1.0,1.4}
    finish = %{" style="fill:red;stroke:green;stroke-width:2" /></svg></div>}
    assert_start_and_finish start,
      finish,
      @calzini.render("star", { "points" => 5, "outer" => 2.0, "inner" => 1.0, "draw_context" => { "fill" => "red", "stroke" => "green" } })
  end

  def test_star_image_pattern
    # Test that image paths create SVG patterns
    html = @calzini.render("star", { "points" => 5, "outer" => 100.0, "inner" => 50.0, "fill" => "avatar.png" })
    assert html.include?("<pattern id=\"star-pattern-elt-1\""), "Should create pattern element"
    assert html.include?("<image href=\"avatar.png\""), "Should include image in pattern"
    assert html.include?("fill:url(#star-pattern-elt-1)"), "Should reference pattern in polygon"
  end
end
