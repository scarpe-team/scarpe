# frozen_string_literal: true

require_relative "test_helper"

class TestDrawContext < NienteTest
  # need tests for:
  # default values vs draw context values
  # setting value explicitly w/ positional or keyword arg

  # Test w/ color string names for now. This reveals a
  # problem - our highly-variable color handling makes it
  # hard to be sure about what comes through in a style.

  # We do a bunch of wacky stuff with colors. We need some kind of
  # equality check. This is good enough for this test until we
  # have a proper color object backing up what we do in Scarpe.
  def assert_color_equal(c1, c2)
    if c1.nil? && c2.nil?
      raise "Is this an expected use case?"
    end

    if (c1.is_a?(String) || c1.is_a?(Symbol)) && (c2.is_a?(String) || c2.is_a?(Symbol))
      return assert_equal c1.to_s, c2.to_s, "Expected color #{c1.inspect} to equal #{c2.inspect}"
    end

    if c1.is_a?(Array) && c2.is_a?(Array)
      return assert_equal c1, c2, "Expected color #{c1.inspect} to equal #{c2.inspect}"
    end

    raise "Oopsie! We got an unexpected comparison between colors #{c1.inspect}"
  end

  def test_draw_context_default
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        oval 5, 10, 25 # circle with radius 25 with its upper-left point at 5, 10
      end
    SHOES_APP
      ov = oval()
      assert_equal "black", ov.style["fill"]
      assert_equal "black", ov.style["stroke"]
    SHOES_SPEC
  end

  def test_draw_context_basic
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        fill darkgreen
        stroke blue
        oval 5, 10, 25 # circle with radius 25 with its upper-left point at 5, 10
      end
    SHOES_APP
      ov = oval()
      assert_equal [0, 100, 0, 255], ov.style["fill"]
      assert_equal [0, 0, 255, 255], ov.style["stroke"]
    SHOES_SPEC
  end

  def test_draw_context_explicit
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        fill blue
        stroke blue
        oval 5, 10, 25, fill: darkgreen
      end
    SHOES_APP
      ov = oval()
      assert_equal [0, 100, 0, 255], ov.style["fill"]
      assert_equal [0, 0, 255, 255], ov.style["stroke"]
    SHOES_SPEC
  end

  def test_draw_context_basic_nofill
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        nofill
        oval 5, 10, 25
      end
    SHOES_APP
      ov = oval()
      assert_equal [0, 0, 0, 0], ov.style["fill"]
    SHOES_SPEC
  end

  def test_draw_context_inherited_nofill
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        nofill
        nostroke
        stack do
          oval 5, 10, 25
        end
      end
    SHOES_APP
      ov = oval()
      assert_equal [0, 0, 0, 0], ov.style["fill"]
      assert_equal [0, 0, 0, 0], ov.style["stroke"]
    SHOES_SPEC
  end

  def test_draw_context_inherited_no_sibling
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        fill yellow
        stroke yellow
        stack do
          fill blue
          stroke darkgreen
          stack do
            fill aquamarine
            stroke aquamarine
          end
          stack do
            oval 5, 10, 25
          end
        end
      end
    SHOES_APP
      ov = oval()
      assert_equal [0, 0, 255, 255], ov.style["fill"]
      assert_equal [0, 100, 0, 255], ov.style["stroke"]
    SHOES_SPEC
  end

  def test_draw_context_inherited_nil_props
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        stack do
          fill blue
          stroke darkgreen
          stack do
            fill nil
            stroke nil
            oval 5, 10, 25
          end
        end
      end
    SHOES_APP
      ov = oval()
      assert_equal [0, 0, 255, 255], ov.style["fill"]
      assert_equal [0, 100, 0, 255], ov.style["stroke"]
    SHOES_SPEC
  end

  def test_draw_context_inherited_cancel_default
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        stack do
          fill blue
          stroke darkgreen
          stack do
            fill yellow
            stroke yellow
            oval 5, 10, 25
            fill nil
            stroke nil
            @o2 = oval 5, 10, 25
          end
        end
      end
    SHOES_APP
      ov = oval("@o2")
      assert_equal [0, 0, 255, 255], ov.style["fill"]
      assert_equal [0, 100, 0, 255], ov.style["stroke"]
    SHOES_SPEC
  end

  # Integration lane: `stroke "#BBB"; button "Expert"` sent the stroke to the Button and
  # to every Para, so control-sizes.rb drew its controls in #dde and minesweeper greyed
  # its buttons. Shoes 3 colours text from its own styles only (s3t_textblock.c:250-258)
  # and its native controls ignore stroke.
  def test_text_and_controls_keep_their_own_colours
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        stroke red
        fill blue
        strokewidth 5
        @p = para "plain ", strong("bold")
        @b = button "Push"
        @e = edit_line
        @eb = edit_box
        @l = list_box items: ["a"]
        @r = rect 0, 0, 10
      end
    SHOES_APP
      %w[@p @b @e @eb @l].each do |name|
        drawable = drawable(name)
        assert_nil drawable.style[:stroke], "\#{name} keeps its own stroke"
      end
      assert_nil para("@p").style[:fill]
      strong = para("@p").contents.last
      assert_equal [nil, nil, nil], [strong.style[:stroke], strong.style[:fill], strong.style[:strokewidth]]
      assert_equal [255, 0, 0, 255], rect("@r").style[:stroke], "shapes still draw with the slot's stroke"
      assert_equal [0, 0, 255, 255], rect("@r").style[:fill]
    SHOES_SPEC
  end

  # Wire contract (b), ledger E10: translate (cumulative), transform and cap travel in
  # the draw context, where they used to be no-ops.
  def test_translate_transform_and_cap_reach_the_shapes
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $returned = [translate(10, 20), cap(:curve)]
        stack do
          translate 5, 5
          transform :center
          @inner = rect 0, 0, 10
        end
        @outer = rect 0, 0, 10
        @line = line 0, 0, 10, 10, cap: :project
      end
    SHOES_APP
      inner = rect("@inner").style[:draw_context]
      assert_equal [[15, 25], :center, :curve], inner.values_at("translate", "transform", "cap")

      outer = rect("@outer").style[:draw_context]
      assert_equal [[10, 20], nil, :curve], outer.values_at("translate", "transform", "cap"),
        "a slot's translate and transform stay in that slot"

      assert_equal :project, line("@line").style[:cap], "a shape's own cap is kept"
      assert_equal [Shoes.APPS.first] * 2, $returned, "translate and cap return self"
    SHOES_SPEC
  end
end
