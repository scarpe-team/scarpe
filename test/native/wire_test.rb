# frozen_string_literal: true

require_relative "helper"

# The bytes the shim writes (native/PERF.md keeps a JSON::State per thread for speed).
class WireTest < Minitest::Test
  include NativeTestHelpers

  MESSAGES = [
    { t: "props", id: 5, props: { "text" => "é ✓   \"quoted\" \\ back", "left" => 1.5, "tiny" => 1e-7, "n" => nil } },
    { t: "create", id: 1, kind: "App", parent: nil, props: { "list" => [1, 2.25, "x", { "a" => [] }] } },
    { t: "flush" },
  ].freeze

  def test_encoding_matches_json_generate_on_every_thread
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "script.json"), "[]")
      ENV["FAKE_CHILD_SCRIPT"] = File.join(dir, "script.json")
      child = Scarpe::Native::Child.new([FAKE_CHILD])
      expected = MESSAGES.map { |m| JSON.generate(m) }
      on_threads = Array.new(4) { Thread.new { 200.times.map { MESSAGES.map { |m| child.send(:encode, m) } } } }.map(&:value)
      on_threads.flatten(1).each { |encoded| assert_equal expected, encoded }
    ensure
      ENV.delete("FAKE_CHILD_SCRIPT")
      child&.close
    end
  end
end
