# frozen_string_literal: true

require "net/http"
require "openssl"
require "nokogiri"

module Shoes
  class Widget
    class ResponseWrapper
      attr_reader :response

      def initialize(response)
        @response = response
      end

      def headers
        @response.each_header.to_h
      end

      def body
        @response.body
      end
    end

    def download(url, method: "GET", save: nil, styles: {}, &block)
      @block = block

      Thread.new do
        logger = Scarpe::Logger.logger("Scarpe::App#download")
        begin
          uri = URI(url)
          response = perform_request(uri, method, styles)

          if response.is_a?(Net::HTTPRedirection)
            new_location = response["location"]
            new_uri = URI(new_location)
            response = perform_request(new_uri, method, styles)
          end

          wrapped_response = ResponseWrapper.new(response) # Wrap the response
          handle_response(wrapped_response, save, styles)
        rescue Net::HTTPError, Net::OpenTimeout, Net::ReadTimeout => e
          handle_error(e, logger)
        rescue StandardError => e
          handle_error(e.message, logger) # Pass the error message as a string
        end
      end
    end

    private

    def perform_request(uri, method, styles)
      port = uri.port || (uri.scheme == "https" ? 443 : 80)
      http = Net::HTTP.start(uri.host, port, use_ssl: uri.scheme == "https", verify_mode: OpenSSL::SSL::VERIFY_NONE)

      request = Net::HTTP.const_get(method.capitalize).new(uri.request_uri)
      apply_styles(request, styles)

      http.request(request)
    end

    def apply_styles(request, styles)
      headers = styles[:headers]
      request["Content-Type"] = headers["Content-Type"] if headers && headers["Content-Type"]
      request.body = styles[:body] if styles[:body]
      # Add more custom styles to the request as needed
    end

    def handle_response(response, save, styles)
      case response.response.code.to_i
      when 200..299
        content = response.body
        # headers = response.headers # Access headers directly
        if save
          save_content(content, save)
          parse_rss(content) # Parse the downloaded XML content
        else
          handle_finish_event(response) # Pass response and headers to handle_finish_event
        end
      else
        handle_failure(response.response.code)
      end
    end

    def save_content(content, file_name)
      file = nil
      begin
        file = File.open(file_name, "w")
        file.write(content)
      rescue Errno::EACCES, Errno::ENOENT => e
        raise FileError, "File error occurred: #{e.message}"
      else
        @block&.call
      ensure
        file&.close
      end
    end

    def handle_finish_event(response)
      passed = Struct.new(:response).new(response) # Create a new Struct with response attribute
      @block&.call(passed) # Pass it ok
    end

    def handle_failure(code, logger)
      logger.error("Failed to download content. Response code: #{code}")
    end

    def handle_error(error, logger)
      logger.error("An error occurred while downloading: #{error}")
    end

    def parse_rss(content)
      doc = Nokogiri::XML(content)
      items = doc.xpath("//item")
      items.each do |item|
        item.xpath("title").text
        item.xpath("link").text
        item.xpath("description").text
        # Do something with the parsed content or use it if needed
      end
    end
  end
end
