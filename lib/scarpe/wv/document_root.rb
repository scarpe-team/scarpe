# frozen_string_literal: true

module Scarpe::Webview
  # A DocumentRoot is a {Scarpe::Webview::Flow}, with all the same properties
  # and basic behavior. It also reserves space for Builtins like fonts, alerts,
  # etc. which don't have individual {Shoes::Drawable} objects.
  class DocumentRoot < Flow
    def initialize(properties)
      super

      @fonts = []
      @alerts = []

      bind_shoes_event(event_name: "builtin") do |cmd_name, args|
        case cmd_name
        when "font"
          @fonts << args[0]
          # Can't just create font_updater and alert_updater on initialize - not everything is set up
          @font_updater ||= Scarpe::Webview::WebWrangler::ElementWrangler.new("root-fonts")
          @font_updater.inner_html = font_contents
        when "alert"
          bind_ok_event
          @alerts << args[0]
          @alert_updater ||= Scarpe::Webview::WebWrangler::ElementWrangler.new("root-alerts")
          @alert_updater.inner_html = alert_contents
        else
          raise Scarpe::UnknownBuiltinCommandError, "Unexpected builtin command: #{cmd_name.inspect}!"
        end
      end
    end

    def element(&block)
      contents = block ? block.call : ""
      super do
        contents + HTML.render do |h|
          h.div(id: "root-fonts") do
            font_contents
          end
          h.div(id: "root-alerts") do
            alert_contents
          end
        end
      end
    end

    private

    # This needs to occur after initialize() because the app isn't yet allocated initially,
    # so we can't call bind() for app events yet.
    def bind_ok_event
      return if @ok_event_setup_done
      @ok_event_setup_done = true

      # Done with the alert(s), delete them
      bind("OK") do
        @alerts = []
        needs_update!
      end
    end

    def font_contents
      HTML.render do |h|
        @fonts.each do |font|
          h.link(href: font, rel: "stylesheet")
          h.style do
            font_name = File.basename(font, ".*")
            <<~CSS
              @font-face {
                font-family: #{font_name};
                src: url("data:font/truetype;base64,#{encode_file_to_base64(font)}") format('truetype');
              }
            CSS
          end
        end
      end
    end

    def alert_contents
      @alerts.map do |alert_text|
        render("alert", { "text" => alert_text, "event_name" => "OK" })
      end.join + " "
    end
  end
end
