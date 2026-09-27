# frozen_string_literal: true

require_relative "helper"

class GalleryTest < Minitest::Test
  def setup
    @results = Dir.mktmpdir("gallery-test-")
    FileUtils.mkdir_p(File.join(@results, "gallery"))
    FileUtils.cp(File.join(SpecSuite::ASSETS_DIR, "red-40x30.png"), File.join(@results, "gallery", "button.png"))
    results_file("native",
      "examples/button.rb" => { "status" => "pass", "message" => "results/gallery/button.png" },
      "examples/legacy/working/clock.rb" => { "status" => "fail", "message" => "Ruby error: undefined method 'x' for <Shoes::App>" })
    results_file("niente",
      "examples/button.rb" => { "status" => "pass", "message" => "exited 0 after 1.2s" },
      "examples/needs_gems.rb" => { "status" => "skip", "message" => "needs the sqlite3 gem" })
  end

  def teardown
    FileUtils.rm_rf(@results)
  end

  def test_it_writes_an_index_next_to_the_snapshots
    path = SpecSuite::Gallery.new(@results).write

    assert_equal File.join(@results, "gallery", "index.html"), path
    assert File.size?(path), "the page is written"
  end

  def test_each_example_gets_its_thumbnail_path_statuses_and_error_line
    html = File.read(SpecSuite::Gallery.new(@results).write)

    assert_includes html, %(<img src="button.png"), "an example with a snapshot shows it as a thumbnail"
    assert_includes html, "examples/legacy/working/clock.rb", "every example in any results file is listed"
    assert_includes html, "examples/needs_gems.rb"
    assert_includes html, "Ruby error: undefined method &#39;x&#39; for &lt;Shoes::App&gt;", "error lines are shown, escaped"
    assert_includes html, "needs the sqlite3 gem", "and so is why an example was skipped"
    refute_includes html, "exited 0 after", "a pass needs no message"
  end

  def test_failures_come_first
    html = File.read(SpecSuite::Gallery.new(@results).write)

    assert_operator html.index("clock.rb"), :<, html.index("button.rb"), "the broken example leads the page"
  end

  private

  def results_file(display, rows)
    document = { "display" => display, "results" => rows }
    File.write(File.join(@results, "examples-#{display}.json"), JSON.generate(document))
  end
end
