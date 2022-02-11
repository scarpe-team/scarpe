# frozen_string_literal: true

require "webview_ruby"
require 'securerandom'

require_relative "scarpe/container"
require_relative "scarpe/version"
require_relative "scarpe/para"
require_relative "scarpe/stack"
require_relative "scarpe/flow"
require_relative "scarpe/button"
require_relative "scarpe/image"
require_relative "scarpe/edit_line"
require_relative "scarpe/internal_app"


module Scarpe
  def self.app(opts = {}, &blk)
    w = WebviewRuby::Webview.new(debug: true)
    internal_app = Scarpe::InternalApp.new(w)
    w.bind("scarpeInit") do
      internal_app.render(&blk)
    end
    w.bind("scarpeHandler") do |*args|
      internal_app.handle_callback(*args)
    end
    w.init("scarpeInit();")
    w.set_title("example")
    w.set_size(480, 320)
    w.navigate("data:text/html, <body id=#{internal_app.object_id}></body>")
    w.run
    w.destroy
  end
end
