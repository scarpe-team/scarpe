# frozen_string_literal: true

require "test_helper"

class TestTextDrawables < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  def require_helper
    "require " + File.expand_path("#{__dir__}/shoes_spec_helper.rb").inspect
  end

  # To test:
  #
  # * LinkHover

  def test_basic_text_drawables
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        para "This is ", em("emphatically"), " ", strong("strongly"), " made of text!"
      end
      ----------- test code
      #{require_helper}
      self.class.include TextDrawableHelper

      assert_equal "This is emphatically strongly made of text!", para.text
      assert_includes trim_html_ids(para.display.to_html), "This is <em>emphatically</em> <strong>strongly</strong> made of text!"
    SSPEC
  end

  def test_para_stroke_and_fill
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        para "This is text", stroke: green, fill: blue
      end
      ----------- test code
      #{require_helper}
      self.class.include TextDrawableHelper

      h = trim_html_ids(para.display.to_html)
      assert_includes h, "This is text"
      assert_includes h, 'color:#008000'
      assert_includes h, 'background-color:#0000FF'
    SSPEC
  end

  def test_styled_text_drawables
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        para "This is ", em("emphatically ", hidden: true), "somewhat hidden!"
      end
      ----------- test code
      #{require_helper}
      self.class.include TextDrawableHelper

      assert_equal "This is emphatically somewhat hidden!", para.text
      assert_includes trim_html_ids(para.display.to_html), \%{This is <em style="display:none">emphatically </em>somewhat hidden!}
    SSPEC
  end

  def test_basic_nested_text_drawables_1
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        para "This is ", em(strong("emphatically strongly")), " made of text!"
      end
      ----------- test code
      #{require_helper}
      self.class.include TextDrawableHelper

      assert_equal "This is emphatically strongly made of text!", para.text
      assert_includes trim_html_ids(para.display.to_html), "This is <em><strong>emphatically strongly</strong></em> made of text!"
    SSPEC
  end

  def test_basic_nested_text_drawables_2
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        para "This is ", em("emphatically and ", strong("empha-strongly")), " made of text!"
      end
      ----------- test code
      #{require_helper}
      self.class.include TextDrawableHelper

      assert_equal "This is emphatically and empha-strongly made of text!", para.text
      assert_includes trim_html_ids(para.display.to_html), "This is <em>emphatically and <strong>empha-strongly</strong></em> made of text!"
    SSPEC
  end

  def test_text_drawable_in_multiple_paras
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        t = em("emphatically")
        @p1 = para "This is ", t, " ", strong("strongly"), " made of text!"
        @p2 = para "And ", t, " a great idea!"
      end
      ----------- test code
      #{require_helper}
      self.class.include TextDrawableHelper

      assert_includes trim_html_ids(para("@p1").display.to_html), "This is <em>emphatically</em> <strong>strongly</strong> made of text!"
      assert_includes trim_html_ids(para("@p2").display.to_html), "And <em>emphatically</em> a great idea!"
    SSPEC
  end

  def test_text_drawable_multiple_para_update
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        @t = em("emphatically")
        @p1 = para "This is ", @t, " ", strong("strongly"), " made of text!"
        @p2 = para "And ", @t, " a great idea!"

        button "Change" do
          @t.text = "totally ", strong("unquestionably")
        end
      end
      ----------- test code
      #{require_helper}
      self.class.include TextDrawableHelper

      button.trigger_click

      # Check to_html updating
      assert_includes trim_html_ids(para("@p1").display.to_html), "This is <em>totally <strong>unquestionably</strong></em> <strong>strongly</strong> made of text!"
      assert_includes trim_html_ids(para("@p2").display.to_html), "And <em>totally <strong>unquestionably</strong></em> a great idea!"

      # Check .text updating
      assert_equal "This is totally unquestionably strongly made of text!", para("@p1").text
      assert_equal "And totally unquestionably a great idea!", para("@p2").text

      # Check dom_html updating
      h = trim_html_ids(dom_html) # Query once
      assert !h.include?("emphatically"), "the word 'emphatically' should have been removed by the update"
      assert_includes h, "This is <em>totally <strong>unquestionably</strong></em> <strong>strongly</strong> made of text!"
      assert_includes h, "And <em>totally <strong>unquestionably</strong></em> a great idea!"
    SSPEC
  end

  def test_span
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        para "This is ", em("emphatically"), " made of ", span("text!")
      end
      ----------- test code
      #{require_helper}
      self.class.include TextDrawableHelper

      assert_equal "This is emphatically made of text!", para.text
      assert_includes trim_html_ids(para.display.to_html), "This is <em>emphatically</em> made of <span>text!</span>"
    SSPEC
  end

  def test_basic_link
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        para "This is ", link(em("emphatically"), " made of ", span("text!"), click: "http://foo.com")
      end
      ----------- test code
      #{require_helper}
      self.class.include TextDrawableHelper

      assert_equal "This is emphatically made of text!", para.text
      assert_includes trim_html_ids(para.display.to_html),
        \%{This is <a href="http://foo.com"><em>emphatically</em> made of <span>text!</span></a>}
    SSPEC
  end

  def test_default_para_size
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        style Shoes::Para, size: 18
        para "This is made of text!"
      end
      ----------- test code
      assert_includes para.display.to_html, "font-size:18px"
    SSPEC
  end

  def test_default_para_size_override
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        style Shoes::Para, size: 14
        para "This is made of text!", size: 19
      end
      ----------- test code
      assert_includes para.display.to_html, "font-size:19px"
    SSPEC
  end

  def test_default_em_size
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        style Shoes::Em, size: 21
        para "This is made of ", em("text!")
      end
      ----------- test code
      assert_includes para.display.to_html, "font-size:21px"
    SSPEC
  end

  def test_default_em_size_override
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        style Shoes::Em, size: 14
        para "This is made of ", em("text!", size: 21)
      end
      ----------- test code
      assert_includes para.display.to_html, "font-size:21px"
    SSPEC
  end

  def test_size_on_para_and_text_drawable
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        para "This is ", em("emphatically", size: 16), " made of text!", size: 14
      end
      ----------- test code
      #{require_helper}
      self.class.include TextDrawableHelper

      assert_includes trim_html_ids(para.display.to_html),
        \%{This is <em style="font-size:16px">emphatically</em> made of text!}
      assert_includes trim_html_ids(para.display.to_html), "font-size:14px"
    SSPEC
  end

  def test_bug_with_confusing_ins_and_inscription
    run_scarpe_sspec_code(<<~SSPEC)
      ---
      ----------- app code
      Shoes.app do
        para "Various ", del("text"), " in ", sub("various"), " ", sup("styles"),
          " can be ", ins("hard to read"), "...\n"
      end
      ----------- test code
      #{require_helper}
      self.class.include TextDrawableHelper

      h = trim_html_ids(dom_html)

      assert_includes trim_html_ids(para.display.to_html),
        \%{Various <del>text</del> in <sub>various</sub> <sup>styles</sup> can be <span style=\"text-decoration-line:underline\"><span>hard to read</span></span>...}
    SSPEC
  end

  def test_tiranti_big_text_para_tags
    run_scarpe_sspec_code(<<~SSPEC, html_renderer: "tiranti")
      ---
      ----------- app code
      Shoes.app do
        para "This is made of text!", size: 26
      end
      ----------- test code
      #{require_helper}
      self.class.include TextDrawableHelper

      assert_equal \%{<h3 id=\"3\" style=\"font-size:26px\">This is made of text!</h3>},
        para.display.to_html
    SSPEC
  end

end
