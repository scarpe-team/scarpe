# frozen_string_literal: true

require_relative "../test_helper"

# Some tests don't cover just a single drawable.
class TestVariousCalzini < Minitest::Test
  def setup
    @calzini = CalziniRenderer.new
  end

  # Test data. For each drawable, include
  # a minimal set of properties to create something
  # basic and default. Then we can add to it and
  # test the resulting HTML.
  #
  # In Shoes3, the vast majority of drawables support
  # both stroke and fill. Here's the list from the
  # Shoes manual minus the ones we already test here:
  #
  # background, banner, caption,
  # code, del, em, flow, image, ins, inscription,
  # link, mask, para, shape, span, stack,
  # strong, sub, sup, subtitle, tagline, title
  #
  # Scarpe doesn't yet support the property on everything.
  # but as we support it, we should add the drawables
  # here.
  #
  CALZINI_ART_DRAWABLES = {
    arc: {
      has_stroke: false,
      has_fill: false,
      props: {
        "width" => 200,
        "height" => 150,
        "left" => 17,
        "top" => 42,
        "angle1" => 3.14 / 2,
        "angle2" => 3.14 / 4,
      },
    },
    arrow: {
      has_stroke: true,
      has_fill: true,
      props: {
        "left" => 10,
        "top" => 20,
        "width" => 5,
      },
    },
    line: {
      has_stroke: true,
      has_fill: false,
      props: {
        "top" => "4",
        "left" => "7",
        "x1" => "20",
        "y1" => "17",
        "x2" => "100",
        "y2" => "104",
      },
    },
    rect: {
      has_stroke: true,
      has_fill: true,
      props: {
        "top" => "9",
        "left" => "12",
        "width" => "147",
        "height" => "91",
        "draw_context" => {},
      },
    },
    star: {
      has_stroke: true,
      has_fill: true,
      props: {
        "points" => 5,
        "outer" => 2.0,
        "inner" => 1.0,
      },
    },
    oval: {
      has_stroke: true,
      has_fill: true,
      props: {
        "left" => 10,
        "top" => 7,
        "radius" => 5,
      },
    },
  }

  # This method tests some basic ways of setting strokes and fills and makes sure they
  # work for different drawables. TODO: add more drawables. TODO: either add testing for
  # setting stroke and fill directly vs. draw-context, or remove draw-context.
  def test_color_conversion
    CALZINI_ART_DRAWABLES.each do |name, h|
      basic = @calzini.render(name.to_s, h[:props])
      assert !basic.include?("#FF0000"), "Un-colored #{name} shouldn't already have red or we'll get a false positive!"

      if h[:has_stroke]
        red_stroke = @calzini.render(name.to_s, h[:props].merge("stroke" => [255, 0, 0, 255]))
        assert_includes red_stroke, "#FF0000", "With integer-array red stroke, #{name} should contain red color!"

        red_stroke = @calzini.render(name.to_s, h[:props].merge("draw_context" => { "stroke" => [255, 0, 0, 255] }))
        assert_includes red_stroke, "#FF0000", "With integer-array red stroke, #{name} should contain red color!"

        red_stroke = @calzini.render(name.to_s, h[:props].merge("stroke" => [255, 0, 0, 255], "draw_context" => { "stroke" => [0, 255, 0, 255] }))
        assert_includes red_stroke, "#FF0000", "Red stroke should take precedence over green, #{name} should contain red color!"

        # TODO: later, after issue #504 is fixed, colors should turn into their hex equivalent
        red_stroke = @calzini.render(name.to_s, h[:props].merge("stroke" => "red"))
        assert_includes red_stroke, "red", "With integer-array red stroke, #{name} should contain red color!"
      end

      if h[:has_fill]
        red_fill = @calzini.render(name.to_s, h[:props].merge("fill" => [255, 0, 0, 255]))
        assert_includes red_fill, "#FF0000", "With integer-array red fill, #{name} should contain red color!"

        red_fill = @calzini.render(name.to_s, h[:props].merge("draw_context" => { "fill" => [255, 0, 0, 255] }))
        assert_includes red_fill, "#FF0000", "With integer-array red fill, #{name} should contain red color!"

        red_fill = @calzini.render(name.to_s, h[:props].merge("fill" => [255, 0, 0, 255], "draw_context" => { "fill" => [0, 255, 0, 255] }))
        assert_includes red_fill, "#FF0000", "Red fill should take precedence over green, #{name} should contain red color!"

        # TODO: later, after issue #504 is fixed, colors should turn into their hex equivalent
        red_fill = @calzini.render(name.to_s, h[:props].merge("fill" => "red"))
        assert_includes red_fill, "red", "With integer-array red fill, #{name} should contain red color!"
      end
    end
  end
end
