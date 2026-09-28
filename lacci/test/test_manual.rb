# frozen_string_literal: true

require_relative "test_helper"

# Shoes.show_manual opens the manual in a window of its own, as Shoes 3's built-in manual did
# ("This manual is a Shoes program itself!", manual 31; ledger K7). It opened a web page.
class TestManual < NienteTest
  def test_the_manual_is_read_in_chapters_and_sections
    require "shoes/manual"
    sections = Shoes::Manual.sections
    assert_equal ["Hello!", "Hello!"], [sections.first.chapter, sections.first.title], "it opens on the first chapter"
    styles = sections.find { |s| s.title == "The Styles Master List" }
    assert_equal "Shoes", styles.chapter
    assert_equal %w[Hello! Shoes Slots Elements AndSoForth], sections.map(&:chapter).uniq
    refute sections.flat_map(&:lines).any? { |line| line.start_with?("layout: default") }, "without the page's front matter"
  end

  # A Mac app started from Finder gets no LANG, so Ruby reads files as US-ASCII. The manual is
  # UTF-8, and in a packaged app Help raised "invalid byte sequence in US-ASCII".
  def test_the_manual_reads_as_utf8_whatever_the_locale
    require "shoes/manual"
    was = Encoding.default_external
    silence_warnings = $VERBOSE
    $VERBOSE = nil
    Encoding.default_external = Encoding::US_ASCII
    sections = Shoes::Manual.sections
    assert_equal "Hello!", sections.first.title
    assert sections.flat_map(&:lines).any? { |line| !line.ascii_only? }, "its non-ASCII text comes through"
  ensure
    Encoding.default_external = was
    $VERBOSE = silence_warnings
  end

  def test_show_manual_opens_a_window_that_turns_pages
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        button("Help") { Shoes.show_manual }
      end
    SHOES_APP
      button.trigger_click
      assert_equal 2, Shoes.APPS.size, "the manual opens in a window of its own"
      manual = Shoes.APPS.last
      assert_equal "The Shoes Manual", manual.style[:title]
      texts = -> { manual.all_drawables.select { |d| d.is_a?(Shoes::Para) }.map(&:text) }
      assert_includes texts.call, "Hello!", "it opens on the first page"
      assert texts.call.any? { |t| t.include?("Shoes is a tiny graphics toolkit") }, "with its text"
      assert texts.call.any? { |t| t.include?('Shoes.app { button("Click me!") { alert("Good job.") } }') }, "and its code"

      link = manual.all_drawables.grep(Shoes::Para).flat_map(&:contents).grep(Shoes::Link).find { |l| l.text == "Built-in Methods" }
      refute_nil link, "the index links every section"
      Shoes::DisplayService.dispatch_event("click", link.linkable_id)
      assert texts.call.any? { |t| t.include?("These methods can be used anywhere throughout Shoes programs.") }, "and a link turns to its page"
      refute texts.call.any? { |t| t.include?("Shoes is a tiny graphics toolkit") }, "in place of the first"
    SHOES_SPEC
  end

  # Shoes 3's manual drew its Colors List and Classes List where the text says {COLORS} and
  # {INDEX} (help.rb color_page, index_page; ledger M38), and showed the pictures beside it.
  # Scarpe's printed the braces and dropped every picture.
  def test_the_manual_draws_its_colours_classes_and_pictures
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        button("Help") { Shoes.show_manual("Colors List") }
      end
    SHOES_APP
      button.trigger_click
      manual = Shoes.APPS.last
      words = -> { manual.all_drawables.grep(Shoes::Para).map(&:text) }
      turn_to = lambda do |title|
        link = manual.all_drawables.grep(Shoes::Para).flat_map(&:contents).grep(Shoes::Link).find { |l| l.text == title }
        Shoes::DisplayService.dispatch_event("click", link.linkable_id)
      end
      refute words.call.any? { |t| t.include?("{COLORS}") }, "no braces"
      assert words.call.any? { |t| t.include?("tomato") && t.include?("rgb(255, 99, 71)") }, "tomato, with its numbers"
      assert_operator words.call.count { |t| t.start_with?("aliceblue", "antiquewhite", "aqua") }, :>=, 3

      turn_to.call("Classes List")
      refute words.call.any? { |t| t.include?("{INDEX}") }
      assert words.call.any? { |t| t.include?("Button") }, "the drawables are listed"

      turn_to.call("Hello!")
      picture = manual.all_drawables.grep(Shoes::Image).find { |i| i.url.to_s.end_with?("man-shot1.png") }
      refute_nil picture, "the first page shows how Shoes looks on Linux"
      assert words.call.any? { |t| t.end_with?("here's how this might look:") }, "under the words that promise it"
    SHOES_SPEC
  end
end
