# frozen_string_literal: true

require_relative "test_helper"

class TestApp < NienteTest
  # Ledger A1, ruled by Q1 (27 Sep 2026): Shoes 3 and Shoes 4 open 600x500, titled "Shoes".
  def test_an_app_with_no_size_opens_at_the_shoes_default
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app { para "sized by default" }
    SHOES_APP
      app = Shoes.APPS.first
      assert_equal [600, 500], [app.width, app.height]
      assert_equal "Shoes", app.style[:title]
    SHOES_SPEC
  end

  # Ledger M14: text is sized in pixels unless a program asks for Shoes 3's text, points at
  # 96 dpi; the display hears of it as a text_mode event.
  def test_text_mode_is_scarpe_unless_a_program_asks_for_shoes3
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      $modes = []
      Shoes::DisplayService.subscribe_to_event("text_mode", nil) { |mode| $modes << mode }
      $before = Shoes.text_mode
      Shoes.text_mode = :shoes3
      Shoes.app { para "Hackety" }
    SHOES_APP
      assert_equal [:scarpe, :shoes3, ["shoes3"]], [$before, Shoes.text_mode, $modes]
      error = assert_raises(ArgumentError) { Shoes.text_mode = :points }
      assert_match(/:scarpe or :shoes3/, error.message)
      assert_equal :shoes3, Shoes.text_mode, "a wrong mode changes nothing"
    SHOES_SPEC
  end

  # Ledger A3: Shoes.app, window and dialog return the new Shoes::App (manual 859,
  # 1958-1961), where Shoes.app ended with nil.
  def test_shoes_app_window_and_dialog_return_the_app
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      $main = Shoes.app do
        $window = window(title: "second") { para "two" }
        $dialog = dialog(title: "third") { para "three" }
      end
    SHOES_APP
      assert_equal Shoes.APPS, [$main, $window, $dialog]
      assert_same $main, $window.owner
    SHOES_SPEC
  end

  # Ledger A8: close shuts its own window while another is open, and that window leaves
  # Shoes.APPS (manual 887-888, 901-904); the last window's close ends everything, as destroy does.
  def test_close_shuts_one_window_and_the_last_one_quits
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      $main = Shoes.app do
        $window = window(title: "second") { para "two" }
      end
    SHOES_APP
      quits = []
      Shoes::DisplayService.subscribe_to_event("destroy", nil) { quits << :everything }
      $window.close
      assert_equal [$main], Shoes.APPS
      assert_empty quits, "the main window stays open"
      $main.close
      assert_equal [:everything], quits
    SHOES_SPEC
  end

  # Ledger J1: location is the URL of the page on show (manual 980-982).
  def test_location_follows_visit
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        url "/", :index
        url "/about", :about
        def index = para("home")
        def about = para("about")
      end
    SHOES_APP
      app = Shoes.APPS.first
      assert_equal "/", app.location
      app.visit("/about")
      assert_equal "/about", app.location
    SHOES_SPEC
  end

  # Ledger M26: started? is false while the app block builds the window and true
  # once it is open (manual 1006-1010).
  def test_started_once_the_window_is_open
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        $during_build = started?
      end
    SHOES_APP
      assert_equal false, $during_build
      assert_equal true, Shoes.APPS.first.started?
    SHOES_SPEC
  end

  # A Shoes app's block runs with the App as self, so its instance variables share a namespace
  # with Lacci's own. Names an app is likely to pick (a list of slots, of pages, a start time)
  # must stay the app's (examples/native/kids/_repros/peekaboo_moles_1.rb, where @slots
  # replaced Lacci's slot stack and the next stack died with NoMethodError on a Hash).
  def test_an_apps_own_instance_variables_leave_lacci_alone
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @slots = [{ x: 10 }, { x: 60 }]
        @pages = %w[one two]
        @routes = :mine
        @location = "Belfast"
        @started = 1966
        @document_root = "mine"
        @content_container = "mine"
        @dir = "mine"
        @do_shutdown = true
        @event_loop_type = "mine"
        @start_callbacks = "mine"
        @external_self_stack = "mine"
        @first_boot_finished = "mine"
        @app_code_body = "mine"
        @watch_for_destroy = "mine"
        @watch_for_event_loop = "mine"
        url "/about", :about
        def about = flow { $about = para("about") }
        page(:extra) { $extra = para("extra") }
        start { $started = true }
        $stack = stack(left: 10, top: 10, width: 100, height: 40) { para "hello" }
      end
    SHOES_APP
      app = Shoes.APPS.first
      assert_equal "hello", $stack.contents.first.text, "the stack after @slots = [...] was built"
      app.visit("/about")
      assert_equal ["about", "/about"], [$about.text, app.location]
      app.visit(:extra)
      assert_equal ["extra", "/extra"], [$extra.text, app.location]
      assert_equal true, $started
      assert_equal true, app.started?
      assert_kind_of Shoes::DocumentRoot, app.document_root
      assert_equal Dir.pwd, app.dir
      assert_equal [{ x: 10 }, { x: 60 }], app.instance_variable_get(:@slots), "and @slots is still the app's"
    SHOES_SPEC
  end

  # Ledger K4: font returns the family names in the file, or nil when it holds none
  # (manual 766-767).
  def test_font_returns_the_families_in_the_file
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      PACIFICO = File.join(Shoes::Constants::DIR, "fonts", "Pacifico.ttf")
      Shoes.app do
        $families = font(PACIFICO)
        $missing = font("no-such-font.ttf")
        $not_a_font = font(__FILE__)
      end
    SHOES_APP
      assert_equal ["Pacifico"], $families
      assert_nil $missing
      assert_nil $not_a_font
      assert_includes Shoes::FONTS, "Pacifico"
    SHOES_SPEC
  end

  # Font names are UTF-16 text, read by hand because a packaged app's Ruby has no encoding
  # transcoders (test/package's test_fonts_are_named_and_loaded_in_the_bundle): a surrogate
  # pair is one character, half a pair alone is U+FFFD, and a Mac Roman name in plain ASCII
  # reads as it is.
  def test_font_names_are_read_without_transcoders
    assert_equal "\u{1D49C} Sans", Shoes::FontFile.send(:utf_16be, "\xD8\x35\xDC\x9C\x00 \x00S\x00a\x00n\x00s".b)
    assert_equal "\uFFFDx", Shoes::FontFile.send(:utf_16be, "\xD8\x00\x00x".b)
    assert_equal "Pacifico", Shoes::FontFile.send(:mac_roman, "Pacifico".b)
  end

  # Ledger D6: background takes an :angle for its gradient (manual 1073-1079).
  def test_a_backgrounds_angle_turns_its_gradient
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @turned = background red..blue, angle: 90
      end
    SHOES_APP
      turned = background("@turned")
      assert_equal 90, turned.style[:angle]
      assert_equal 90, turned.fill.angle, "the angle travels with the gradient itself"
    SHOES_SPEC
  end
end
