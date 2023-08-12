# frozen_string_literal: true

# Lacci is one place we put components that have no hard gem requirements.
# It needs to connect to Scarpe, mostly via the Shoes DisplayService.
# Some display services, like Wasm, cannot install or otherwise tolerate
# Scarpe's need for a variety of gems, especially those with native extensions.
# So we need a simple require-able Scarpe core here in Lacci that can be
# required from display services that cannot link with the base Scarpe gem.

if RUBY_VERSION[0..2] < "3.2"
  Shoes::Log.logger("Scarpe").error("Scarpe requires Ruby 3.2 or higher!")
  exit(-1)
end

# Is there a Shoes::Error class? Should this be two different error classes?
class Scarpe; end
class Scarpe::Error < StandardError; end

require "lacci/version"
require "scarpe/components/version"
