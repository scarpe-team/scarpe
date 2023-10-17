# frozen_string_literal: true

require "test_helper"

# Drawables Testing
class TestDrawables < LoggedScarpeTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  def test_hide_show
    run_test_scarpe_code(<<-'SCARPE_APP', app_test_code: <<-'TEST_CODE')
      Shoes.app do
        @drawables = []
        @drawables << arc(400, 0, 120, 100, 175, 175)
        @drawables << button("Press Me")
        @drawables << check
        @drawables << edit_line("foo")
        @drawables << edit_box("bar")
        @drawables << flow {} # Slightly weird thing here: empty flow
        @drawables << image("https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png")
        @drawables << line(0, 0, 100, 100)
        @drawables << list_box(items: ['A', 'B'])
        @drawables << para("Hello")
        @drawables << radio("ooga")
        @drawables << rect(0, 0, 50, 100, 5)
        @drawables << shape { line(0, 0, 10, 10) }
        @drawables << stack {}
        @drawables << star(230, 100, 6, 50, 25)
        @drawables << video("http://techslides.com/demos/sample-videos/small.mp4")
      end
    SCARPE_APP
      on_heartbeat do
        # Get proxy objects for the Shoes drawables so we can get their display objects, etc.
        w = Shoes::App.instance.instance_variable_get("@drawables").map { |sw| proxy_for(sw) }

        w.each { |i| i.hide }
        w.each { |i| assert_include i.display.to_html, "display:none" }
        w.each { |i| i.toggle() }
        w.each { |i| assert_not_include i.display.to_html, "display:none" }

        # Nothing hidden, make sure no display:none
        wait fully_updated
        assert_not_include dom_html, "display:none"

        # Exactly one thing hidden
        para.hide
        wait fully_updated
        # Okay, so what's weird about this is that if we use the DOM style setter to set display, it gets a space...
        assert_include dom_html, "display: none"

        test_finished
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
      on_heartbeat do
        assert_equal [], stack("@s2").contents
        js = button.display.handler_js_code('click')
        query_js_value(js)

        test_finished
      end
    TEST_CODE
  end
end
