# frozen_string_literal: true

module Scarpe::Webview
  class Image < Drawable
    def initialize(properties)
      super

      # Bind click/hover/leave events (like Button)
      bind("click") do
        send_self_event(event_name: "click")
      end

      bind("hover") do
        send_self_event(event_name: "hover")
      end

      bind("leave") do
        send_self_event(event_name: "leave")
      end

      if @url.nil? || @url.empty?
        # Blank/spacer image — transparent 1x1 PNG (Shoes3 supports image(w,h) for spacers)
        @url = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
      elsif !(valid_url?(@url) || @url.start_with?("data:"))
        # It's assumed to be a file path.
        @url = Scarpe::Webview.asset_server.asset_url(File.expand_path @url)
      end
    end

    def element
      render("image")
    end
  end
end
