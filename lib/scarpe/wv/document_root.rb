# frozen_string_literal: true

require "open3"

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
          @font_updater ||= Scarpe::Webview::WebWrangler::ElementWrangler.new(html_id: "root-fonts")
          @font_updater.inner_html = font_contents
        when "alert"
          bind_ok_event
          @alerts << args[0]
          @alert_updater ||= Scarpe::Webview::WebWrangler::ElementWrangler.new(html_id: "root-alerts")
          @alert_updater.inner_html = alert_contents
        when "ask"
          result = native_ask_dialog(args[0])
          Shoes::DisplayService.set_builtin_response(result)
        when "confirm"
          result = native_confirm_dialog(args[0])
          Shoes::DisplayService.set_builtin_response(result)
        when "ask_color"
          result = native_color_dialog(args[0])
          Shoes::DisplayService.set_builtin_response(result)
        when "ask_open_file"
          result = native_open_file_dialog
          Shoes::DisplayService.set_builtin_response(result)
        when "ask_save_file"
          result = native_save_file_dialog
          Shoes::DisplayService.set_builtin_response(result)
        when "ask_open_folder"
          result = native_open_folder_dialog
          Shoes::DisplayService.set_builtin_response(result)
        when "ask_save_folder"
          result = native_open_folder_dialog  # Same dialog, different intent
          Shoes::DisplayService.set_builtin_response(result)
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

    # Escape a string for use inside AppleScript double-quoted strings.
    def applescript_escape(str)
      str.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
    end

    # Show a native text input dialog. Returns the entered text, or nil if cancelled.
    def native_ask_dialog(message)
      escaped = applescript_escape(message)
      script = %Q{display dialog "#{escaped}" default answer "" buttons {"Cancel", "OK"} default button "OK"}
      stdout, status = safe_osascript(script)
      if status.success?
        # Output format: "button returned:OK, text returned:whatever"
        match = stdout.match(/text returned:(.*)/)
        match ? match[1].strip : ""
      else
        "" # User cancelled — return empty string for Shoes3 compatibility
      end
    rescue => e
      "" # Return empty string on error for Shoes3 compatibility
    end

    # Show a native confirmation dialog. Returns true for OK, false for Cancel.
    def native_confirm_dialog(question)
      escaped = applescript_escape(question)
      script = %Q{display dialog "#{escaped}" buttons {"Cancel", "OK"} default button "OK"}
      _stdout, status = safe_osascript(script)
      status.success?
    rescue => e
      false
    end

    # Show a native color picker dialog. Returns an rgb() color string or nil.
    def native_color_dialog(title)
      escaped = applescript_escape(title || "Choose a color")
      script = %Q{choose color with prompt "#{escaped}"}
      stdout, status = safe_osascript(script)
      if status.success?
        # Output format: "{65535, 0, 32768}" — values 0-65535
        match = stdout.match(/\{(\d+),\s*(\d+),\s*(\d+)\}/)
        if match
          r = (match[1].to_i / 257.0).round
          g = (match[2].to_i / 257.0).round
          b = (match[3].to_i / 257.0).round
          Shoes.rgb(r, g, b)
        end
      end
    rescue => e
      nil
    end

    # Show a native file open dialog. Returns the file path or nil.
    def native_open_file_dialog
      script = 'POSIX path of (choose file with prompt "Open")'
      stdout, status = safe_osascript(script)
      status.success? ? stdout.strip : nil
    rescue => e
      nil
    end

    # Show a native file save dialog. Returns the file path or nil.
    def native_save_file_dialog
      script = 'POSIX path of (choose file name with prompt "Save as")'
      stdout, status = safe_osascript(script)
      status.success? ? stdout.strip : nil
    rescue => e
      nil
    end

    # Show a native folder picker dialog. Returns the folder path or nil.
    def native_open_folder_dialog
      script = 'POSIX path of (choose folder with prompt "Choose a folder")'
      stdout, status = safe_osascript(script)
      status.success? ? stdout.strip : nil
    rescue => e
      nil
    end

    # Safely execute osascript without threading issues.
    # Uses Open3.popen3 with explicit stream handling to avoid
    # "IOError: stream closed in another thread" race conditions.
    def safe_osascript(script)
      stdout_data = ""
      wait_thread = nil
      
      Open3.popen3("osascript", "-e", script) do |stdin, stdout, stderr, thread|
        stdin.close
        stdout_data = stdout.read
        stderr.close
        wait_thread = thread
      end
      
      [stdout_data, wait_thread.value]
    end
  end
end
