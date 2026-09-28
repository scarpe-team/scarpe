# frozen_string_literal: true

# Boots an app packaged by `scarpe package --native` (docs/native_packaging.md). The launcher
# (Contents/MacOS/scarpe-launcher) has set up Traveling Ruby, put Scarpe, Lacci and
# scarpe-components on RUBYLIB, pointed SCARPE_NATIVE_BIN at the Rust binary beside it, and passes
# the app's file name. This is Contents/Resources/boot.rb, so __dir__ is the bundle's Resources.

# A packaged app knows its display service, whatever the environment it was started from says.
ENV["SCARPE_DISPLAY_SERVICE"] = "native"

# Finder, the Dock and `open` start an app with no LANG, so Ruby would read every file as US-ASCII
# and choke on a program with an accented letter in it, or on the manual. It reads UTF-8, as a Mac
# terminal does.
Encoding.default_external = Encoding::UTF_8 if Encoding.default_external == Encoding::US_ASCII

# Precompiled Ruby, when it was compiled for this place and this Ruby. SCARPE_BYTECODE=0 skips it.
require "scarpe/package/bytecode"
Scarpe::Package::Bytecode.install(__dir__) unless ENV["SCARPE_BYTECODE"] == "0"

require "scarpe"
require "scarpe/package/yjit"
Scarpe::Package::YJIT.enable_after_first_frame

# SCARPE_RUN_FILE runs that file with this app's Ruby and Scarpe instead of the app's own: how a
# packaged app's Shoes.run_program starts a program (native/DESIGN.md 5.5).
if (run_file = ENV["SCARPE_RUN_FILE"])
  Scarpe::Native::ProgramChild.run(run_file)
else
  Shoes.run_app(File.join(__dir__, "app", ARGV.fetch(0)))
end
