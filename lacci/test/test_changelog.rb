# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

# Ledger L3: Shoes::REVISION names the checkout's commit even when the app runs from
# another directory, as every spec sandbox does.
class TestChangelog < Minitest::Test
  def test_revision_comes_from_the_checkout_not_the_working_directory
    revision = Dir.chdir(Dir.tmpdir) { Shoes::Changelog.new.get_latest_release_info[:REVISION] }
    assert_match(/\A\h{40}\z/, revision.to_s)
  end

  # A packaged app starts with no LANG, so Ruby reads files as US-ASCII, and requiring Lacci
  # raised in String#scan once CHANGELOG.md held a "»".
  def test_release_info_reads_a_utf8_changelog_whatever_the_locale
    Dir.mktmpdir do |root|
      File.write(File.join(root, "CHANGELOG.md"), "## [0.9.1] - 2026-09-27 - Noah\n\n- methods marked » self\n")
      info = with_default_external(Encoding::US_ASCII) { Shoes::Changelog.new.get_latest_release_info(root) }
      assert_equal ["Noah", "2026-09-27", 901], info.values_at(:RELEASE_NAME, :RELEASE_BUILD_DATE, :RELEASE_ID)
    end
  end

  private

  def with_default_external(encoding)
    verbose, $VERBOSE = $VERBOSE, nil
    saved = Encoding.default_external
    Encoding.default_external = encoding
    yield
  ensure
    Encoding.default_external = saved
    $VERBOSE = verbose
  end
end
