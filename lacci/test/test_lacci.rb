# frozen_string_literal: true

require_relative "test_helper"

class TestLacci < NienteTest
  def test_simple_button_click
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @b = button "OK" do
          @b.text = "Yup"
        end
      end
    SHOES_APP
      button().trigger_click
      assert_equal "Yup", button().text
    SHOES_SPEC
  end

  def test_positional_default_values
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        star 15, 35
      end
    SHOES_APP
      s = star()
      assert_equal 10, s.points
      assert_equal 50, s.inner
    SHOES_SPEC
  end

  def test_positional_args
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        star 10, 25, 8 # Leave outer and inner as default
      end
    SHOES_APP
      s = star()
      assert_equal 10, s.left
      assert_equal 25, s.top
      assert_equal 8, s.points
      assert_equal 50, s.inner
    SHOES_SPEC
  end

  def test_keyword_args
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        star 5, 6, points: 8, inner: 30
      end
    SHOES_APP
      s = star()
      assert_equal 5, s.left
      assert_equal 6, s.top
      assert_equal 8, s.points
      assert_equal 100, s.outer
      assert_equal 30, s.inner
    SHOES_SPEC
  end

  def test_too_many_positional_args
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack {}
      end
    SHOES_APP
      s = stack("@s")
      assert_raises Shoes::Errors::BadArgumentListError do
        s.star 5, 6, 7, 8, 9, 10, 11
      end
    SHOES_SPEC
  end

  def test_too_few_positional_args
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack {}
      end
    SHOES_APP
      s = stack("@s")
      assert_raises Shoes::Errors::BadArgumentListError do
        s.star 5
      end
    SHOES_SPEC
  end

  def test_mouse_returns_default_state
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @m = self.mouse
      end
    SHOES_APP
      m = Shoes.APPS[0].instance_variable_get(:@m)
      assert_equal [0, 0, 0], m
    SHOES_SPEC
  end

  def test_window_as_shoes_app
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      window :title => "Test Window", :width => 500, :height => 300 do
        @p = para "Window works!"
      end
    SHOES_APP
      assert_equal "Window works!", para().text
    SHOES_SPEC
  end

  def test_app_width_height_accessible
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app :width => 600, :height => 400 do
        @w = self.width
        @h = self.height
      end
    SHOES_APP
      w = Shoes.APPS[0].instance_variable_get(:@w)
      h = Shoes.APPS[0].instance_variable_get(:@h)
      assert_equal 600, w
      assert_equal 400, h
    SHOES_SPEC
  end

  def test_slot_computed_dimensions
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app :width => 600, :height => 400 do
        # document_root has width: "100%", height: "100%"
        # These should resolve to the App's dimensions
        @slot_w = app.slot.width
        @slot_h = app.slot.height

        # Nested stack with percentage width
        @nested_stack = stack :width => "50%" do
          para "nested"
        end

        # Nested stack with negative height (means parent height minus N)
        @negative_stack = stack :height => -50 do
          para "negative"
        end
      end
    SHOES_APP
      slot_w = Shoes.APPS[0].instance_variable_get(:@slot_w)
      slot_h = Shoes.APPS[0].instance_variable_get(:@slot_h)
      nested_stack = Shoes.APPS[0].instance_variable_get(:@nested_stack)
      negative_stack = Shoes.APPS[0].instance_variable_get(:@negative_stack)

      # Document root (100%) should equal App dimensions
      assert_equal 600, slot_w
      assert_equal 400, slot_h

      # 50% of 600 = 300
      assert_equal 300, nested_stack.width

      # Parent height (400) minus 50 = 350
      assert_equal 350, negative_stack.height
    SHOES_SPEC
  end

  def test_mouse_reflects_display_service_state
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        Shoes::DisplayService.mouse_state = [1, 150, 200]
        @m = self.mouse
      end
    SHOES_APP
      m = Shoes.APPS[0].instance_variable_get(:@m)
      assert_equal [1, 150, 200], m
    SHOES_SPEC
  end

  # Shoes 3 kept the pointer per app (app->mousex, app->mousey), so a window just opened reads
  # [0, 0, 0] until the pointer is over it. A display that tells windows apart hands Lacci one
  # state per app; Hackety Hack's Pong read the pointer over Hackety Hack's own Run button and
  # started its paddle off its window.
  def test_mouse_is_per_window_when_the_display_says_which
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app { para "first" }
    SHOES_APP
      first = Shoes.APPS[0]
      begin
        Shoes::DisplayService.mouse_state = [0, 764, 530]
        assert_equal [0, 764, 530], first.mouse, "one pointer for every window, from a display that keeps one"
        Shoes::DisplayService.app_mouse_states[first.linkable_id] = [1, 20, 30]
        assert_equal [1, 20, 30], first.mouse, "its own, from one that keeps one a window"
        assert_equal [0, 0, 0], Shoes::DisplayService.mouse_state_of(first.linkable_id + 1000), "and a window the pointer never crossed reads 0, 0, 0"
      ensure
        Shoes::DisplayService.app_mouse_states.clear
      end
    SHOES_SPEC
  end

  def test_builtin_response_mechanism
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "test"
      end
    SHOES_APP
      # Test the builtin response mechanism directly
      Shoes::DisplayService.clear_builtin_response
      assert_nil Shoes::DisplayService.consume_builtin_response

      Shoes::DisplayService.set_builtin_response("hello")
      assert_equal "hello", Shoes::DisplayService.consume_builtin_response

      # Should be consumed (nil on second read)
      assert_nil Shoes::DisplayService.consume_builtin_response
    SHOES_SPEC
  end

  def test_builtin_response_false_value
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "test"
      end
    SHOES_APP
      # false is a valid response (e.g. confirm returning false)
      Shoes::DisplayService.clear_builtin_response
      Shoes::DisplayService.set_builtin_response(false)
      result = Shoes::DisplayService.consume_builtin_response
      assert_equal false, result
    SHOES_SPEC
  end

  def test_clipboard_accessor
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "test"
      end
    SHOES_APP
      app = Shoes.APPS[0]
      # clipboard should return a string (may be empty)
      result = app.clipboard
      assert_kind_of String, result

      # clipboard= should accept a string
      app.clipboard = "scarpe test"
      assert_equal "scarpe test", app.clipboard
    SHOES_SPEC

    assert_equal "scarpe test", File.read(clipboard_file), "the copy lands in the stub, not the real clipboard"
  end

  def test_shoes_builtin_returns_response
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "test"
      end
    SHOES_APP
      # Set up a test handler that responds to a custom builtin
      handler_id = Shoes::DisplayService.subscribe_to_event("builtin", nil) do |cmd_name, args, **kwargs|
        if cmd_name == "ask"
          Shoes::DisplayService.set_builtin_response("test_response")
        end
      end

      # Call shoes_builtin which should now return the response
      app = Shoes.APPS[0]
      result = app.send(:shoes_builtin, "ask", "What?")
      assert_equal "test_response", result

      Shoes::DisplayService.unsub_from_events(handler_id)
    SHOES_SPEC
  end

  # Ledger C5: path is the image's url and swaps it, full_width and full_height read the
  # file, and imagesize reads a file without showing it (manual 2017-2023, 3143-3164).
  def test_image_path_and_sizes_from_the_file
    red = File.expand_path("../../spec/support/assets/red-40x30.png", __dir__)
    checker = File.expand_path("../../spec/support/assets/checker-20x20.png", __dir__)
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $size = imagesize(#{checker.inspect})
        @img = image #{red.inspect}, width: 80, height: 90
      end
    SHOES_APP
      img = image()
      assert_equal [40, 30], [img.full_width, img.full_height]
      assert_equal #{red.inspect}, img.path
      img.path = #{checker.inspect}
      assert_equal #{checker.inspect}, img.url, "path= swaps the picture"
      assert_equal [20, 20], $size
      assert_equal 1, images.size, "imagesize showed nothing"
    SHOES_SPEC
  end

  def test_image_rotate
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @img = image "http://example.com/test.png"
        @img.rotate(45)
      end
    SHOES_APP
      img = image()
      assert_equal 45, img.rotate_angle
    SHOES_SPEC
  end

  def test_image_transform_center
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @img = image "http://example.com/test.png"
        @img.transform :center
      end
    SHOES_APP
      img = image()
      assert_equal "center", img.transform_origin
    SHOES_SPEC
  end

  def test_slot_finish_callback
    # In Shoes3, finish is called when the slot is REMOVED, not after init
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @result = "not finished"
        @s = stack do
          para "hello"
        end
        # Register finish callback
        @s.finish { @result = "finished!" }
        # Destroy the stack to trigger finish callbacks
        @s.destroy
      end
    SHOES_APP
      result = Shoes.APPS[0].instance_variable_get(:@result)
      assert_equal "finished!", result
    SHOES_SPEC
  end

  def test_stack_scroll_top
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @s = stack :scroll => true do
          para "hello"
        end
      end
    SHOES_APP
      s = stack("@s")
      assert_equal 0, s.scroll_top
      s.scroll_top = 50
      assert_equal 50, s.scroll_top
    SHOES_SPEC
  end

  # --- Para cursor/marker/hit system tests ---

  def test_para_cursor_integer
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "Hello World"
      end
    SHOES_APP
      p = para()
      assert_nil p.cursor
      p.cursor = 5
      assert_equal 5, p.cursor
      p.cursor = 0
      assert_equal 0, p.cursor
      p.cursor = nil
      assert_nil p.cursor
    SHOES_SPEC
  end

  def test_para_marker
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "Hello World"
      end
    SHOES_APP
      p = para()
      assert_nil p.marker
      p.marker = 3
      assert_equal 3, p.marker
      p.marker = nil
      assert_nil p.marker
    SHOES_SPEC
  end

  def test_para_highlight_no_selection
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "Hello World"
      end
    SHOES_APP
      p = para()
      p.cursor = 5
      sel = p.highlight
      assert_equal [5, 0], sel
    SHOES_SPEC
  end

  def test_para_highlight_with_selection
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "Hello World"
      end
    SHOES_APP
      p = para()
      p.cursor = 8
      p.marker = 3
      sel = p.highlight
      assert_equal [3, 5], sel
    SHOES_SPEC
  end

  def test_para_highlight_reverse_selection
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "Hello World"
      end
    SHOES_APP
      p = para()
      p.cursor = 2
      p.marker = 9
      sel = p.highlight
      assert_equal [2, 7], sel
    SHOES_SPEC
  end

  # Shoes 3.1's cursor = :marker drops the selection: the caret goes to its start and the
  # marker is cleared (s3t_textblock.c:602-616, ledger F14). It used to jump to the marker and
  # keep it, so in Hackety Hack's editor a second Backspace did nothing and typing after
  # Backspace or select-all came out backwards: `alert "hello"`, two Backspaces and `p!"`
  # read `alert "hello"!p`.
  def test_para_cursor_marker_drops_the_selection
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "Hello World"
      end
    SHOES_APP
      p = para()
      p.cursor = 5
      p.marker = 10
      p.cursor = :marker
      assert_equal [5, nil], [p.cursor, p.marker], "a selection ahead of the caret"
      p.cursor = 10
      p.marker = 3
      p.cursor = :marker
      assert_equal [3, nil], [p.cursor, p.marker], "one behind it"
      p.cursor = :marker
      assert_equal [3, nil], [p.cursor, p.marker], "with no marker nothing moves"
      p.marker = 7
      p.cursor = nil
      assert_equal [nil, nil], [p.cursor, p.marker], "nil takes the caret and the marker away"
    SHOES_SPEC
  end

  # How Hackety Hack's editor types: an edit puts the caret after it and then says
  # cursor = :marker (app/ui/editor/editor.rb:291-301).
  def test_para_typing_after_a_backspace_goes_forward
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "hello"
      end
    SHOES_APP
      p = para()
      text = +"hello"
      p.cursor = 5
      2.times do # Backspace: select the letter before the caret, delete the selection
        p.marker = p.cursor - 1 if p.marker.nil?
        pos, len = p.highlight
        text[pos, len] = ""
        p.cursor = pos
        p.cursor = :marker
      end
      "p!".each_char do |c|
        pos, _len = p.highlight
        text.insert(pos, c)
        p.cursor = pos + 1
        p.cursor = :marker
      end
      assert_equal ["help!", 5, nil], [text, p.cursor, p.marker]
    SHOES_SPEC
  end

  def test_para_cursor_top_default
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "Hello World"
      end
    SHOES_APP
      p = para()
      assert_equal 0, p.cursor_top
    SHOES_SPEC
  end

  def test_para_hit_default
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @p = para "Hello World"
      end
    SHOES_APP
      p = para()
      assert_nil p.hit(100, 100)
    SHOES_SPEC
  end

  def test_unsupported_feature
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC, expect_process_fail: true)
      Shoes.app(features: :html) do
        para "Not supported by Niente, though."
      end
    SHOES_APP
      assert true
    SHOES_SPEC
  end

  def test_unknown_feature
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app(features: :squid) do
        para "No such feature, though."
      end
    SHOES_APP
      assert true
    SHOES_SPEC
  end

  # `style` looks up a class's style names on every change an animation makes, so each
  # class keeps its list; a style declared later, even on a parent, is still found.
  def test_style_names_are_kept_and_still_follow_new_styles
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      class Shoes
        class CacheParent < Shoes::Drawable
          shoes_style :first
        end

        class CacheChild < CacheParent
          shoes_style :second
        end
      end
      Shoes.app {}
    SHOES_APP
      names = Shoes::CacheChild.shoes_style_names
      assert_same names, Shoes::CacheChild.shoes_style_names, "worked out once"
      assert names.frozen?, "and kept safe from its callers"
      assert_includes names, "first"
      Shoes::CacheParent.shoes_style :third
      assert_includes Shoes::CacheChild.shoes_style_names, "third", "a parent's new style reaches the child"
      assert_includes Shoes::CacheChild.shoes_style_names(with_features: :all), "third"
    SHOES_SPEC
  end
end
