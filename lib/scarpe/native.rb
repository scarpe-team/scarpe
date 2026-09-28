# frozen_string_literal: true

# Scarpe Native: Ruby keeps Lacci and every user block, a Rust child process draws.
# Selected with SCARPE_DISPLAY_SERVICE=native (or `scarpe --native app.rb`).
# The protocol and the rules this code follows live in native/DESIGN.md.
#
# Never load this alongside scarpe/wv: both set the once-only Shoes::Log and Shoes::Spec globals.

require "json"

module Scarpe
  module Native
    ROOT = File.expand_path("../..", __dir__)
  end
end

require_relative "native/log"
Shoes::Log.instance = Scarpe::Native::LogImpl.new
Shoes::Log.configure_logger(Shoes::Log::DEFAULT_LOG_CONFIG)

require "scarpe/components/segmented_file_loader"
Shoes.add_file_loader Scarpe::Components::SegmentedFileLoader.new

require_relative "native/normalize"
require_relative "native/child"
require_relative "native/timers"
require_relative "native/builtins"
require_relative "native/automation"
require_relative "native/pump"
require_relative "native/programs"
require_relative "native/program_child"
require_relative "native/display_drawable"
require_relative "native/display_service"

# Shoes-Spec needs minitest, 10-45 ms to load (native/PERF.md), and only a spec run uses it: Lacci
# runs the code in SHOES_SPEC_TEST. Packaged apps may leave minitest out; they lose Shoes-Spec only.
if ENV["SHOES_SPEC_TEST"]
  begin
    require "minitest"
    require_relative "native/shoes_spec"
    Shoes::Spec.instance = Scarpe::Native::Test
  rescue LoadError
    Shoes::Spec.instance = nil
  end
end

Shoes::FEATURES.push(:multi_app)
Shoes::FONTS.push("Inter", "Helvetica", "Arial", "Times New Roman", "Georgia", "Courier", "Menlo", "Monaco", "Verdana")

Shoes::DisplayService.set_display_service_class(Scarpe::Native::DisplayService)

# Builtins may be called before any Shoes.app (the manual allows `ask_open_file` at the top level),
# so the answer is wired to the bus now rather than when the service first exists.
Shoes::DisplayService.subscribe_to_event("builtin", nil) do |cmd_name, args, **_kwargs|
  Shoes::DisplayService.display_service.builtin(cmd_name, args || [])
end

# Every builtin is answered by the subscription above, so falling through to Lacci's osascript
# dialogs can only be a bug, and a real dialog popping up mid test run is the one bug we never want.
module Scarpe::Native::NoOsascriptFallback
  private

  def native_builtin_fallback(*)
    nil
  end
end
Shoes::Builtins.prepend(Scarpe::Native::NoOsascriptFallback)
