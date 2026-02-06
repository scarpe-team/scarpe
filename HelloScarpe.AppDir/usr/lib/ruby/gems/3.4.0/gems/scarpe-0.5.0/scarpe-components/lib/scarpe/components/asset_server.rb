# frozen_string_literal: true

require "webrick"

module Scarpe; module Components; end; end
class Scarpe::Components::AssetServer
  include Scarpe::Components::Base64
  include Shoes::Log

  attr_reader :port
  attr_reader :server_started
  attr_reader :dir

  URL_TYPES = [:auto, :asset, :data]

  # Port 0 will auto-assign a free port
  def initialize(port: 0, app_dir:, never_start_server: false, connect_timeout: 5)
    log_init("AssetServer")

    require "scarpe/components/base64"

    @server_started = false
    @server_thread = nil
    @port = port != 0 ? port : find_open_port
    @app_dir = File.expand_path app_dir
    @components_dir = File.expand_path "#{__dir__}/../../.."
    @connect_timeout = connect_timeout
    @never_start_server = never_start_server

    # For now, always use 16kb as the cutoff for preferring to serve a file with the asset server
    @auto_asset_url_size = 16 * 1024

    # Make sure the child process is dead
    at_exit do
      kill_server
    end
  end

  # Get an asset URL for the given url or filename.
  # The asset server can return a data URL, which encodes
  # the entire file into the URL. It can return an asset
  # server URL, which will serve the file via a local
  # webrick server (@see AssetServer).
  #
  # If url_type is auto, asset_url will return a data URL
  # or asset server URL depending on file size and whether
  # it's local to the asset server. Remote URLs will always
  # be returned verbatim.
  #
  # @param url [String] the filename or URL
  # @param url_type [Symbol] the type of URL to return - one of :auto, :asset, :data
  def asset_url(url, url_type: :auto)
    unless URL_TYPES.include?(url_type)
      raise ArgumentError, "The url_type arg must be one of #{URL_TYPES.inspect}!"
    end

    if valid_url?(url)
      # This is already not local, use it directly
      return url
    end

    # Invalid URLs are assumed to be file paths.
    url = File.expand_path url
    file_size = File.size(url)

    # Calculate the app-relative path to the file. If it's not outside the app
    # dir, great, use that. If it *is* outside the app dir, see if the
    # scarpe-components dir is better (e.g. for Tiranti Bootstrap CSS assets.)
    relative_app_path = relative_path_from_to(@app_dir, url)
    relative_path = relative_app_path
    if relative_app_path.start_with?("../")
      relative_comp_path = relative_path_from_to(@components_dir, url)
      relative_path = relative_comp_path unless relative_comp_path.start_with?("../")
    end

    # If url_type is :auto, we will use a data URL for small files and files that
    # would be outside the asset server's directory. Data URLs are less efficient
    # for large files, but we'll try to always serve *something* if we can.
    if url_type == :data ||
      (url_type == :auto && file_size < @auto_asset_url_size) ||
      (url_type == :auto && relative_path.start_with?("../"))

      # The MIME media type for this file
      file_type = mime_type_for_filename(url)

      # Up to 16kb per file, inline it directly to avoid an extra HTTP request
      return "data:#{file_type};base64,#{encode_file_to_base64(url)}"
    end

    # Start the server if we're returning an asset-server URL
    unless @server_started || @never_start_server
      start_server_thread
    end

    if relative_path.start_with?("../")
      raise Scarpe::OperationNotAllowedError, "Large asset is outside of application directory and asset URL was requested: #{url.inspect}"
    end
    if relative_path == relative_app_path
      "http://127.0.0.1:#{@port}/app/#{relative_path}"
    else
      "http://127.0.0.1:#{@port}/comp/#{relative_path}"
    end
  end

  def find_open_port
    require "socket"
    s = TCPServer.new('127.0.0.1', port)
    port = s.addr[1]
    s.close
    port
  end

  def port_is_responding?(port, timeout: 0.1)
    Socket.tcp("127.0.0.1", port, connect_timeout: timeout) { true } rescue false
  end

  def retry_port(port, timeout: 2.0)
    t = Time.now
    loop do
      resp = port_is_responding?(port)

      return true if resp
      return false if Time.now - t > timeout
      sleep 0.1
    end
  end

  def relative_path_from_to(from, to)
    require 'pathname'
    Pathname.new(to).relative_path_from(Pathname.new from).to_s
  end

  def start_server_thread
    return if @server_started

    @server_thread = Thread.new do
      start_webrick
    end
    @server_started = true

    # Give the asset server a couple of seconds to respond
    retry_port(@port, timeout: @connect_timeout)
    unless port_is_responding?(@port, timeout: 0.1)
      @log.warn "Asset server port doesn't seem to be responding after #{@connect_timeout} seconds!"
    end
  end

  def start_webrick
    require "tempfile"
    log = WEBrick::Log.new Tempfile.new("scarpe_asset_server_log")
    access_log = [
      [Tempfile.new("scarpe_asset_server_access_log"), WEBrick::AccessLog::COMBINED_LOG_FORMAT]
    ]

    @server = WEBrick::HTTPServer.new(Port: @port, DocumentRoot: @app_dir, Logger: log, AccessLog: access_log)
    @server.mount('/app', FileServlet, { Type: :app, Prefix: "/app", DocumentRoot: @app_dir })
    @server.mount('/comp', FileServlet, { Type: :scarpe_components, Prefix: "/comp", DocumentRoot: @components_dir })

    @server.start

    # Set up a signal trap to gracefully shut down the server on interrupt (e.g., Ctrl+C)
    trap('INT') do
      @server.shutdown
    end
  end

  def kill_server
    return unless @server_started && @server_thread

    @server.shutdown
    @server_thread.join if @server_thread.alive?
    @server_started = false
    @server_thread = nil
  end

  # Define a custom servlet to handle file requests
  # Webrick config adapted from ChetankumarSB's local_file_server example
  class FileServlet < WEBrick::HTTPServlet::AbstractServlet
    FS_TYPES = [:app, :scarpe_components]

    def inspect
      "<FileServlet #{@fs_opts[:Type].inspect}>"
    end

    def initialize(server, options)
      @fs_opts = options
      unless options[:Type]
        raise "Internal error! FileServlet expects to know what root it's serving!"
      end
      unless FS_TYPES.include?(options[:Type])
        raise "Internal error! Unknown FileServlet root type #{options[:Type].inspect}!"
      end

      super
    end

    def do_GET(request, response)
      relative_path = request.path.delete_prefix(@fs_opts[:Prefix])
      path = File.join(@fs_opts[:DocumentRoot], relative_path)

      if File.exist?(path) && !File.directory?(path)
        begin
          file_content = File.read(path)

          response.status = 200
          response['Content-Type'] = WEBrick::HTTPUtils.mime_type(path, WEBrick::HTTPUtils::DefaultMimeTypes)
          response.body = file_content
        rescue StandardError => e
          STDERR.puts "Error serving asset: #{e.inspect}"
          response.status = 500
          response.body = 'Internal Server Error'
        end
      else
        response.status = 404
        response.body = 'File not found'
      end
    end
  end
end
