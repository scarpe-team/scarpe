# frozen_string_literal: true

require "test_helper"

# Drawables Testing
class TestDrawables < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  def test_hide_show
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        @drawables = []
        @drawables << arc(400, 0, 120, 100, 175, 175)
        @drawables << arrow(100, 100, 30)
        @drawables << button("Press Me")
        @drawables << check
        @drawables << edit_line("foo")
        @drawables << edit_box("bar")
        @drawables << flow {} # Slightly weird thing here: empty flow
        @drawables << image("https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png")
        @drawables << line(0, 0, 100, 100)
        @drawables << list_box(items: ['A', 'B'])
        @drawables << para("Hello")
        @drawables << progress
        @drawables << radio("ooga")
        @drawables << rect(0, 0, 50, 100, 5)
        @drawables << shape { line(0, 0, 10, 10) }
        @drawables << stack {}
        @drawables << star(230, 100, 6, 50, 25)
        @drawables << video("http://techslides.com/demos/sample-videos/small.mp4")
      end
    SCARPE_APP
      # Get proxy objects for the Shoes drawables so we can get their display objects, etc.
      w = Shoes::App.instance.instance_variable_get("@drawables").map do |sw|
        drawable("id:#{sw.linkable_id}")
      end

      w.each { |i| i.hide }
      w.each do |i|
        assert i.display.to_html.include?("display:none"), "expected drawable #{i.class} to be hidden!"
      end
      w.each { |i| i.toggle() }
      w.each { |i| assert !i.display.to_html.include?("display:none"), "Expected drawable #{i.class} to be shown!" }

      # Nothing hidden, make sure no display:none
      assert !dom_html.include?("display:none")

      # Exactly one thing hidden
      para.hide

      # Okay, so what's weird about this is that if we use the DOM style setter to set display, it gets a space...
      assert_includes dom_html, "display: none", "expected DOM HTML to have a single display:none after hiding para!"

      # Let's test that every drawable has a div with its HTML ID as the outermost element
      # so that a .remove() works correctly.
      w.each do |i|
        d = i.display
        html = d.to_html
        unless html =~ /\A<([^>]+)>/
          assert false, "Can't parse first tag from #{html.inspect}!"
        end
        first_tag = $1

        assert html.include?("id=\"#{d.html_id}"), "#{d.class} doesn't use an outer div with html_id correctly! #{html}"
      end
    TEST_CODE
  end

  def test_app_method
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      class NotADrawable
        def self.magic(stack)
          stack.app do
            @s2.para "Hello!"
          end
        end
      end

      Shoes.app do
        @s = stack do
          button("Press Me") { NotADrawable.magic(@s) }
        end
        @s2 = stack {}
      end
    SCARPE_APP
      assert_equal [], stack("@s2").contents
      button.trigger_click

      assert_equal "Hello!", para.text
    TEST_CODE
  end
end
