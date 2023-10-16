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
          needs_update!
        when "alert"
          bind_ok_event
          @alerts << args[0]
          needs_update!
        else
          raise Scarpe::UnknownBuiltinCommandError, "Unexpected builtin command: #{cmd_name.inspect}!"
        end
      end
    end

    def element(&block)
      contents = block ? block.call : ""
      contents += builtin_contents
      super { contents }
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

    def builtin_contents
      font_contents = @fonts.map do |font|
        HTML.render do |h|
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
      end.join
      alert_contents = @alerts.map do |alert_text|
        render("alert", { "text" => alert_text, "event_name" => "OK" })
      end.join

      font_contents + alert_contents
    end
  end
end
