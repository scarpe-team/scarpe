# frozen_string_literal: true

require "webview_ruby"
require "securerandom"
require "json"

require_relative "scarpe/app"
require_relative "scarpe/widget"
require_relative "scarpe/dimensions"
require_relative "scarpe/html"
require_relative "scarpe/container"
require_relative "scarpe/version"
require_relative "scarpe/para"
require_relative "scarpe/stack"
require_relative "scarpe/flow"
require_relative "scarpe/button"
require_relative "scarpe/image"
require_relative "scarpe/edit_line"
require_relative "scarpe/alert"
require_relative "scarpe/js_eval"
require_relative "scarpe/internal_app"

class Scarpe
  class << self
    def app(opts = {}, &blk)
      app = Scarpe::App.new(opts, &blk)
      app.init
      app.run
      app.destroy
    end
  end
end
