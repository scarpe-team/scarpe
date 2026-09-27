# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "minitest/mock"

# Ledger L3: Shoes::REVISION names the checkout's commit even when the app runs from
# another directory, as every spec sandbox does.
class TestChangelog < Minitest::Test
  LACCI_CHECKOUT = File.expand_path("../..", __dir__)

  def test_revision_comes_from_the_checkout_not_the_working_directory
    revision = Dir.chdir(Dir.tmpdir) { Shoes::Changelog.new.get_latest_release_info[:REVISION] }
    assert_match(/\A\h{40}\z/, revision.to_s)
  end

  # Running git cost 13 to 19 ms at every require, and printed "fatal: not a git
  # repository" wherever git disagreed with the checkout.
  def test_revision_is_read_without_running_git
    expected = IO.popen(["git", "-C", LACCI_CHECKOUT, "rev-parse", "HEAD"], &:read).chomp
    revision = IO.stub(:popen, ->(*) { flunk "ran a process to read the revision" }) do
      Shoes::Changelog.new.get_latest_release_info(LACCI_CHECKOUT)[:REVISION]
    end
    assert_equal expected, revision
  end

  def test_revision_follows_a_worktree_to_its_packed_branch
    Dir.mktmpdir do |dir|
      commit = "0123456789abcdef0123456789abcdef01234567"
      git_dir = File.join(dir, "main.git", "worktrees", "wt")
      FileUtils.mkdir_p(git_dir)
      File.write(File.join(git_dir, "HEAD"), "ref: refs/heads/topic\n")
      File.write(File.join(git_dir, "commondir"), "../..\n")
      File.write(File.join(dir, "main.git", "packed-refs"), "# pack-refs with: peeled\n#{commit} refs/heads/topic\n")
      checkout = File.join(dir, "wt")
      FileUtils.mkdir_p(checkout)
      File.write(File.join(checkout, ".git"), "gitdir: ../main.git/worktrees/wt\n")

      info = nil
      capture_io { info = Shoes::Changelog.new.get_latest_release_info(checkout) }
      assert_equal commit, info[:REVISION]
    end
  end

  def test_no_revision_outside_a_checkout
    Dir.mktmpdir do |dir|
      info = nil
      assert_output("No release found in CHANGELOG.md\n") { info = Shoes::Changelog.new.get_latest_release_info(dir) }
      assert_nil info[:REVISION]
    end
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
