# frozen_string_literal: true

module Scarpe
  class Package
    # YJIT for packaged native apps: on by default, switched on once the app is up rather than at
    # process start. The Ruby that gains from it runs every frame (animate, every and motion
    # handlers), while compiling during boot delayed the first frame by about 20 ms
    # (docs/native_packaging.md). RUBY_YJIT_ENABLE=0 keeps it off; a Ruby built without YJIT
    # (Traveling Ruby 3.4.7 is one) skips it.
    module YJIT
      module_function

      # Arranges for yjit to be enabled on the first heartbeat. Returns whether it will be.
      def enable_after_first_frame(env: ENV, yjit: (RubyVM::YJIT if defined?(RubyVM::YJIT)))
        return false unless yjit.respond_to?(:enable) && !yjit.enabled?
        return false if env["RUBY_YJIT_ENABLE"] == "0"

        Scarpe::Native.on_first_heartbeat { yjit.enable }
        true
      end
    end
  end
end
