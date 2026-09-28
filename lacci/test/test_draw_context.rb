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

  # Ledger E10: rotate turns the pen by so many degrees more, as Shoes 3's
  # cairo_matrix_rotate on the canvas matrix does (s3_ruby.h:472-480). A slot inherits
  # its parent's turn, clear keeps it, and rotate(nil) drops the slot's own.
  def test_rotate_adds_up_within_a_slot
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        rotate 30
        rotate 15
        @first = rect 0, 0, 10
        stack do
          rotate 5
          @inner = rect 0, 0, 10
        end
        @spinner = stack { rotate 1 }
        @spinner.clear { rotate 1 }
        @spinner.clear { rotate 1; @again = rect 0, 0, 10 }
        rotate nil
        @reset = rect 0, 0, 10
      end
    SHOES_APP
      turn = ->(name) { rect(name).style[:draw_context]["rotate"] }

      assert_equal 45, turn.("@first"), "two turns in one slot add up"
      assert_equal 50, turn.("@inner"), "a slot starts from its parent's turn"
      assert_equal 48, turn.("@again"), "and keeps turning through clear, as rotating-star.rb needs"
      assert_nil turn.("@reset"), "rotate nil drops the slot's own turn"
    SHOES_SPEC
  end

  # Ledger D8: strokewidth is honoured on every shape, not only through the draw
  # context; ledger E2: rect and arc take center: as oval does (manual 1115-1121).
  def test_every_shape_keeps_its_own_strokewidth
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $shapes = [rect(0, 0, 5, strokewidth: 6), line(0, 0, 5, 5, strokewidth: 6),
          arc(0, 0, 5, 5, 0, 1, strokewidth: 6), arrow(5, 5, 5, strokewidth: 6),
          star(5, 5, strokewidth: 6), oval(0, 0, 5, strokewidth: 6)]
        $centred = [rect(50, 50, 20, 10, center: true), arc(50, 50, 20, 10, 0, 1, center: true)]
      end
    SHOES_APP
      assert_equal [6] * 6, $shapes.map { |shape| shape.style[:strokewidth] }
      assert_equal [true, true], $centred.map { |shape| shape.style[:center] }
    SHOES_SPEC
  end

  # style(scale:) and style(skew:) are draw-context settings as rotate is (DrawContext::SETTINGS),
  # so they reach the display the same way; they only set an instance variable before
  # (examples/native/kids/_repros/paint_puddles_1.rb). A bare number scales both ways, as the
  # scale method's does, and a bare skew leans along x.
  def test_style_sends_every_draw_context_setting
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $sent = []
        Shoes::DisplayService.subscribe_to_event("prop_change", :any) do |changes, **_kwargs|
          $sent << changes if (changes.keys & Shoes::DrawContext::SETTINGS).any?
        end
        @box = rect 10, 10, 60, 60
        @box.style(rotate: 45)
        @box.style(scale: [2, 3])
        @box.style(scale: 2)
        @box.style(skew: 10)
        @box.style(transform: :center, cap: :curve)
      end
    SHOES_APP
      assert_equal [{ "rotate" => 45 }, { "scale" => [2, 3] }, { "scale" => [2, 2] }, { "skew" => [10, 0] },
        { "transform" => :center, "cap" => :curve }], $sent
      assert_equal [10, 0], Shoes.APPS[0].instance_variable_get(:@box).instance_variable_get(:@skew), "and the drawable keeps it"
    SHOES_SPEC
  end

  # move and displace change two styles and tell the display in one prop_change, so the
  # display never lays out a drawable moved across but not yet down (Peekaboo Moles moved its
  # moles through style(left:, top:) to get one message).
  def test_move_and_displace_tell_the_display_once
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $sent = []
        Shoes::DisplayService.subscribe_to_event("prop_change", :any) do |changes, **_kwargs|
          $sent << changes if (changes.keys & %w[left top displace_left displace_top]).any?
        end
        @box = stack(left: 10, top: 10, width: 50, height: 50) {}
        @box.move(40, "20px")
        @box.displace(3, 4)
      end
    SHOES_APP
      box = stack("@box")
      assert_equal [{ "left" => 40, "top" => "20px" }, { "displace_left" => 3, "displace_top" => 4 }], $sent
      assert_equal [40, "20px"], [box.style[:left], box.style[:top]]
    SHOES_SPEC
  end
end
