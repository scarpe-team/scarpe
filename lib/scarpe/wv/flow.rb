# frozen_string_literal: true

module Scarpe::Webview
  class Flow < Slot
    def initialize(properties)
      super

      bind_shoes_event(event_name: "scroll_top") do |value|
        wrangler = Scarpe::Webview::DisplayService.instance.wrangler
        wrangler.dom_change("document.getElementById('#{html_id}').scrollTop = #{value.to_i}; true")
      end
    end
  end
end
