# frozen_string_literal: true

require_relative "helper"

# Cold start (native/PERF.md): the Ruby side never waits on the child while it could be working.
class StartupTest < Minitest::Test
  # A child that takes a second to answer hello, the way a cold font cache can.
  SLOW_CHILD = <<~RUBY
    $stdout.sync = true
    $stdin.gets
    sleep 1
    puts '{"t":"ready","v":1,"version":"slow"}'
    $stdin.each_line {}
  RUBY

  # One that answers at once.
  PROMPT_CHILD = <<~RUBY
    $stdout.sync = true
    $stdin.gets
    puts '{"t":"ready","v":1,"version":"prompt"}'
    $stdin.each_line {}
  RUBY

  # These stand-ins need no gems. Under `bundle exec` they would inherit RUBYOPT=-rbundler/setup
  # and spend most of a second resolving the bundle on a slow runner, which the timings below
  # would count against the child (a Linux container missed the 0.8 s this way).
  WITHOUT_BUNDLER = { "RUBYOPT" => nil }.freeze

  def test_hello_goes_out_and_ruby_carries_on_without_waiting_for_ready
    started = monotonic
    child = Scarpe::Native::Child.new([WITHOUT_BUNDLER, RbConfig.ruby, "-e", SLOW_CHILD])
    assert_operator monotonic - started, :<, 0.5, "Child.new came back before the answer"
    assert_equal "slow", child.version, "and the answer is there when asked for"
    assert_operator monotonic - started, :>=, 1.0
  ensure
    child&.close
  end

  # Ruby runs the app body between spawning the child and the pump's first look at its answer,
  # so a slow body is not a slow child (review: a 20 s body raised a false ChildTimeout).
  def test_a_long_app_body_is_not_taken_for_a_child_that_never_answered
    child = Scarpe::Native::Child.new([WITHOUT_BUNDLER, RbConfig.ruby, "-e", PROMPT_CHILD], ready_timeout: 0.3)
    # The app body; ready sits unread in the pipe meanwhile. Ruby takes longer to start on Windows.
    sleep Gem.win_platform? ? 2.0 : 0.5
    child.check_started!
    assert_equal "prompt", child.version
  ensure
    child&.close
  end

  def test_a_child_that_never_answers_hello_is_reported_not_waited_on_forever
    child = Scarpe::Native::Child.new([RbConfig.ruby, "-e", "$stdin.each_line {}"], ready_timeout: 0.3)
    child.check_started!
    sleep 0.4
    error = assert_raises(Scarpe::Native::ChildTimeout) { child.check_started! }
    assert_match(/did not answer hello within 0.3s/, error.message)
  ensure
    child&.close
  end

  def test_loading_the_native_display_service_leaves_net_http_and_minitest_for_later
    script = <<~RUBY
      ENV["SCARPE_DISPLAY_SERVICE"] = "native"
      require "scarpe"
      print [defined?(Net::HTTP), defined?(Minitest)].inspect
    RUBY
    load_path = %w[lib lacci/lib scarpe-components/lib].flat_map { |dir| ["-I", File.join(NativeTestHelpers::ROOT, dir)] }
    out = IO.popen([{ "SHOES_SPEC_TEST" => nil }, RbConfig.ruby, *load_path, "-e", script], err: File::NULL, &:read)
    assert_equal "[nil, nil]", out, "only an http image or a Shoes-Spec run needs them"
  end

  private

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
