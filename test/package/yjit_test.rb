# frozen_string_literal: true

require_relative "helper"

ENV["SCARPE_DISPLAY_SERVICE"] = "native"
ENV["SCARPE_NATIVE_LOG_LEVEL"] ||= "error"
require "scarpe"
require "scarpe/package/yjit"

# Packaged apps switch YJIT on once they are up, not at process start (it cost the first frame
# about 20 ms), unless RUBY_YJIT_ENABLE=0 says no or the Ruby has no YJIT.
class YJITTest < Minitest::Test
  FakeYJIT = Struct.new(:enabled) do
    def enabled? = enabled
    def enable = self.enabled = true
  end

  def test_yjit_comes_on_at_the_first_heartbeat
    yjit = FakeYJIT.new(false)

    assert Scarpe::Package::YJIT.enable_after_first_frame(env: {}, yjit: yjit)
    refute yjit.enabled?, "not while the app boots"

    heartbeat
    assert yjit.enabled?
  end

  def test_ruby_yjit_enable_0_keeps_it_off
    yjit = FakeYJIT.new(false)

    refute Scarpe::Package::YJIT.enable_after_first_frame(env: { "RUBY_YJIT_ENABLE" => "0" }, yjit: yjit)
    heartbeat
    refute yjit.enabled?
  end

  def test_a_ruby_without_yjit_skips_it
    refute Scarpe::Package::YJIT.enable_after_first_frame(env: {}, yjit: nil)
  end

  def test_yjit_already_on_is_left_alone
    refute Scarpe::Package::YJIT.enable_after_first_frame(env: {}, yjit: FakeYJIT.new(true))
  end

  private

  def heartbeat
    Shoes::DisplayService.dispatch_event("heartbeat", nil)
  end
end
