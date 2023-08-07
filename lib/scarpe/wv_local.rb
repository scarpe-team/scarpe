# frozen_string_literal: true

require_relative "wv"
require_relative "wv/webview_local_display"

require "bloops"

Shoes::DisplayService.set_display_service_class(Scarpe::WebviewDisplayService)
