# frozen_string_literal: true

# MiniAssetServer - WEBrick-free asset server for Scarpe
# Potential savings: ~837KB (268KB webrick gem + 569KB native extensions)
#
# Drop-in replacement for Scarpe::Components::AssetServer
# Uses only socket.bundle which Scarpe already requires
#
# Enable by setting SCARPE_MINI_ASSET_SERVER=1 or using directly

require 'socket'
require 'uri'

module Scarpe
  module Components
    class MiniAssetServer
      include Scarpe::Components::Base64
      # Conditionally include logging if available
      include Shoes::Log if defined?(Shoes::Log)

      MIME_TYPES = {
        '.html' => 'text/html', '.htm' => 'text/html',
        '.css' => 'text/css',
        '.js' => 'application/javascript',
        '.json' => 'application/json',
        '.png' => 'image/png',
        '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg',
        '.gif' => 'image/gif',
        '.svg' => 'image/svg+xml',
        '.ico' => 'image/x-icon',
        '.webp' => 'image/webp',
        '.woff' => 'font/woff',
        '.woff2' => 'font/woff2',
        '.ttf' => 'font/ttf',
        '.otf' => 'font/otf',
        '.eot' => 'application/vnd.ms-fontobject',
        '.mp3' => 'audio/mpeg',
        '.wav' => 'audio/wav',
        '.mp4' => 'video/mp4',
        '.webm' => 'video/webm',
        '.txt' => 'text/plain',
        '.rb' => 'text/plain',
        '.xml' => 'application/xml',
      }.freeze

      URL_TYPES = [:auto, :asset, :data].freeze

      attr_reader :port, :server_started, :dir

      # Port 0 will auto-assign a free port
      def initialize(port: 0, app_dir:, never_start_server: false, connect_timeout: 5)
        # Only init logging if Shoes::Log is fully set up (has instance)
        if respond_to?(:log_init) && defined?(Shoes::Log) && Shoes::Log.instance
          log_init("MiniAssetServer")
        end

        require "scarpe/components/base64"

        @server_started = false
        @server_thread = nil
        @tcp_server = nil
        @running = false
        @port = port != 0 ? port : find_open_port
        @app_dir = File.expand_path(app_dir)
        @components_dir = File.expand_path("#{__dir__}/../../..")
        @connect_timeout = connect_timeout
        @never_start_server = never_start_server
        @auto_asset_url_size = 16 * 1024

        at_exit { kill_server }
      end

      # Get an asset URL for the given url or filename.
      # Compatible with AssetServer#asset_url
      #
      # @param url [String] the filename or URL
      # @param url_type [Symbol] the type of URL to return - one of :auto, :asset, :data
      def asset_url(url, url_type: :auto)
        unless URL_TYPES.include?(url_type)
          raise ArgumentError, "The url_type arg must be one of #{URL_TYPES.inspect}!"
        end

        return url if valid_url?(url)

        url = File.expand_path(url)
        file_size = File.size(url)

        relative_app_path = relative_path_from_to(@app_dir, url)
        relative_path = relative_app_path
        if relative_app_path.start_with?("../")
          relative_comp_path = relative_path_from_to(@components_dir, url)
          relative_path = relative_comp_path unless relative_comp_path.start_with?("../")
        end

        if url_type == :data ||
           (url_type == :auto && file_size < @auto_asset_url_size) ||
           (url_type == :auto && relative_path.start_with?("../"))

          file_type = mime_type_for_filename(url)
          return "data:#{file_type};base64,#{encode_file_to_base64(url)}"
        end

        unless @server_started || @never_start_server
          start_server_thread
        end

        if relative_path.start_with?("../")
          raise Scarpe::OperationNotAllowedError,
                "Large asset is outside of application directory and asset URL was requested: #{url.inspect}"
        end

        prefix = (relative_path == relative_app_path) ? "/app" : "/comp"
        "http://127.0.0.1:#{@port}#{prefix}/#{relative_path}"
      end

      def find_open_port
        s = TCPServer.new('127.0.0.1', 0)
        port = s.addr[1]
        s.close
        port
      end

      def port_is_responding?(p, timeout: 0.1)
        Socket.tcp("127.0.0.1", p, connect_timeout: timeout) { true }
      rescue
        false
      end

      def retry_port(p, timeout: 2.0)
        t = Time.now
        loop do
          return true if port_is_responding?(p)
          return false if Time.now - t > timeout
          sleep 0.1
        end
      end

      def relative_path_from_to(from, to)
        require 'pathname'
        Pathname.new(to).relative_path_from(Pathname.new(from)).to_s
      end

      def start_server_thread
        return if @server_started

        @server_thread = Thread.new { run_server }
        @server_started = true

        retry_port(@port, timeout: @connect_timeout)
        unless port_is_responding?(@port, timeout: 0.1)
          warn "MiniAssetServer: port not responding after #{@connect_timeout}s"
        end
      end

      def run_server
        @tcp_server = TCPServer.new('127.0.0.1', @port)
        @port = @tcp_server.addr[1] if @port == 0
        @running = true

        while @running
          begin
            client = @tcp_server.accept
            Thread.new(client) { |c| handle_request(c) }
          rescue IOError
            break  # Server was shutdown
          rescue => e
            # Connection error, continue
          end
        end
      end

      def handle_request(client)
        request_line = client.gets
        return unless request_line

        method, path, _ = request_line.split(' ')
        return unless method == 'GET'

        # Read and discard headers
        while (line = client.gets) && line != "\r\n"; end

        path = URI.decode_www_form_component(path)
        file_path = resolve_path(path)

        if file_path && File.exist?(file_path) && !File.directory?(file_path)
          serve_file(client, file_path)
        else
          serve_404(client, path)
        end
      rescue => e
        # Connection errors - silently ignore
      ensure
        client.close rescue nil
      end

      def resolve_path(request_path)
        roots = {
          '/app' => @app_dir,
          '/comp' => @components_dir
        }

        roots.each do |prefix, root|
          if request_path.start_with?(prefix)
            relative = request_path.delete_prefix(prefix)
            relative = relative.delete_prefix('/')
            full_path = File.expand_path(File.join(root, relative))
            # Security: ensure path doesn't escape root
            return full_path if full_path.start_with?(root)
          end
        end
        nil
      end

      def mime_type(path)
        ext = File.extname(path).downcase
        MIME_TYPES[ext] || 'application/octet-stream'
      end

      def serve_file(client, path)
        content = File.binread(path)
        headers = [
          "HTTP/1.1 200 OK",
          "Content-Type: #{mime_type(path)}",
          "Content-Length: #{content.bytesize}",
          "Cache-Control: no-cache",
          "Connection: close",
          "",
          ""
        ].join("\r\n")
        client.write(headers)
        client.write(content)
      end

      def serve_404(client, path)
        body = "File not found: #{path}"
        headers = [
          "HTTP/1.1 404 Not Found",
          "Content-Type: text/plain",
          "Content-Length: #{body.bytesize}",
          "Connection: close",
          "",
          ""
        ].join("\r\n")
        client.write(headers)
        client.write(body)
      end

      def kill_server
        return unless @server_started

        @running = false
        @tcp_server&.close
        @server_thread&.join(1)
        @server_started = false
        @server_thread = nil
      end

      private

      def valid_url?(url)
        url =~ /\Ahttps?:\/\//
      end

      def mime_type_for_filename(path)
        mime_type(path)
      end
    end
  end
end
