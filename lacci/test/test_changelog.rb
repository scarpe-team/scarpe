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
end
