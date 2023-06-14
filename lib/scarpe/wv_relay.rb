# frozen_string_literal: true

require_relative "wv"
require_relative "wv/webview_relay_display"

Scarpe::DisplayService.set_display_service_class(Scarpe::WVRelayDisplayService)
