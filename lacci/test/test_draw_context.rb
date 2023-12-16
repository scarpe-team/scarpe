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
end
