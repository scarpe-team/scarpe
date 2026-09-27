# frozen_string_literal: true

require_relative "helper"

class SandboxTest < Minitest::Test
  def test_case_names_differing_only_in_punctuation_get_separate_sandboxes
    names = %w[manual/widgets-text/check.checked?.sspec manual/widgets-text/check.checked=.sspec]
      .map { |path| SpecSuite::Sandbox.dir_name(path) }

    assert_equal 2, names.uniq.size, "check.checked? and check.checked= must not share a directory: #{names.inspect}"
  end

  def test_sandbox_names_stay_readable_and_stable
    name = SpecSuite::Sandbox.dir_name("manual/styles/styles.width.sspec")

    assert name.start_with?("manual_styles_styles.width.sspec-"), "the case path still leads the name: #{name}"
    assert_equal name, SpecSuite::Sandbox.dir_name("manual/styles/styles.width.sspec"), "the same case gets the same name"
    assert_match(/\A[\w.-]+\z/, name, "and the name is safe as one path component")
  end

  # A case's temp files and downloads must not outlive it or reach the next case: the image
  # cache was shared through the real TMPDIR, and element.image.remote__cached could find an
  # earlier run's entry for the same port.
  def test_temp_files_and_downloads_stay_inside_the_sandbox
    Dir.mktmpdir do |parent|
      sandbox = SpecSuite::Sandbox.new(parent, "case")
      env = sandbox.env("native")

      assert_equal File.join(sandbox.root, "tmp"), env["TMPDIR"]
      assert File.directory?(env["TMPDIR"]), "made up front, or Dir.tmpdir falls back to the shared one"
      assert_equal File.join(sandbox.root, "cache"), env["SCARPE_NATIVE_CACHE"]
    end
  end

  def test_the_renderer_names_itself_inside_the_sandbox
    Dir.mktmpdir do |parent|
      sandbox = SpecSuite::Sandbox.new(parent, "case")
      assert_equal File.join(sandbox.root, "renderer.pid"), sandbox.env("native")["SCARPE_NATIVE_PID_FILE"]
    end
  end
end
