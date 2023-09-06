# frozen_string_literal: true

require_relative "wv"
require_relative "wv/webview_local_display"

Shoes::DisplayService.set_display_service_class(Scarpe::Webview::DisplayService)
