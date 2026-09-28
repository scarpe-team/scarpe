# frozen_string_literal: true

class Shoes
  class Drawable
    class ResponseWrapper
      attr_reader :response

      # @param saved [Boolean] true when the data went to a file, so body is nil
      def initialize(response, saved: false)
        @response = response
        @saved = saved
      end

      # HTTP status code (e.g., 200, 404, 500)
      def status
        @response.code.to_i
      end

      # HTTP status code (alias for status)
      def code
        status
      end

      def headers
        @response.each_header.to_h
      end

      # The data, or nil when save: wrote it to a file (manual 950-952).
      def body
        @saved ? nil : @response.body
      end
    end

    # What start, progress and finish are handed (manual 906-975): the response once it
    # has arrived, and how much of it has.
    class Download
      attr_reader :url
      attr_accessor :response, :length, :transferred

      def initialize(url)
        @url = url
        @length = 0
        @transferred = 0
      end

      # @return [Integer] how much has arrived, from 0 to 100
      def percent
        length.zero? ? 0 : transferred * 100 / length
      end
    end

    # Fetch url on a background thread and return at once (manual 906-975). The download
    # fires start, progress and finish, each handed the Download; a block is the finish
    # event. save: writes the data to that file, leaving response.body nil. method:,
    # headers: and body: shape the request (manual 954-960; ledger K5).
    #
    # @return [Thread] the download's thread
    def download(url, method: "GET", headers: {}, body: nil, save: nil,
                 start: nil, progress: nil, finish: nil, styles: {}, &block)
      require "net/http"
      require "openssl"

      finish ||= block
      headers = (styles[:headers] || {}).merge(headers)
      body ||= styles[:body]

      Thread.new do
        logger = Shoes::Log.logger("Shoes::App#download")
        begin
          dl = Download.new(url)
          start&.call(dl)

          response = perform_request(URI(url), method, headers, body)
          response = perform_request(URI(response["location"]), method, headers, body) if response.is_a?(Net::HTTPRedirection)

          if response.is_a?(Net::HTTPSuccess)
            arrived(dl, response, save, progress)
            finish&.call(dl)
          else
            handle_failure(response.code, logger)
          end
        rescue Net::HTTPError, Net::OpenTimeout, Net::ReadTimeout => e
          handle_error(e, logger)
        rescue StandardError => e
          handle_error(e.message, logger) # Pass the error message as a string
        end
      end
    end

    private

    def perform_request(uri, method, headers, body)
      port = uri.port || (uri.scheme == "https" ? 443 : 80)
      http = Net::HTTP.start(uri.host, port, use_ssl: uri.scheme == "https", verify_mode: OpenSSL::SSL::VERIFY_NONE)

      request = Net::HTTP.const_get(method.to_s.capitalize).new(uri.request_uri)
      headers.each { |name, value| request[name.to_s] = value.to_s }
      request.body = body if body

      http.request(request)
    end

    # The whole response has been read, so progress fires once, at 100 percent.
    def arrived(dl, response, save, progress)
      content = response.body.to_s
      dl.length = dl.transferred = content.bytesize
      progress&.call(dl)

      File.binwrite(save, content) if save
      dl.response = ResponseWrapper.new(response, saved: !save.nil?)
    end

    def handle_failure(code, logger)
      logger.error("Failed to download content. Response code: #{code}")
    end

    def handle_error(error, logger)
      logger.error("An error occurred while downloading: #{error}")
    end
  end
end
