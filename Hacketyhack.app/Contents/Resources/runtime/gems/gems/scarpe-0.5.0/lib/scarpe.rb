# frozen_string_literal: true

if RUBY_VERSION[0..2] < "3.2"
  Shoes::Log.logger("Scarpe").error("Scarpe requires Ruby 3.2 or higher!")
  exit(-1)
end

require "shoes"
require "lacci/scarpe_core"

d_s = ENV["SCARPE_DISPLAY_SERVICE"] || "wv_local"
# This is require, not require_relative, to allow gems to supply a new display service
require "scarpe/errors"
require "scarpe/#{d_s}"
