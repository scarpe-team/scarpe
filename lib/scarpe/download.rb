# frozen_string_literal: true

class Scarpe
  class Widget
    def download(url, method: "GET", save: nil, styles: {}, &block)
      @block = block

      Thread.new do
        logger = ::Scarpe::Logger.logger("Scarpe::App#download")
        begin
          uri = URI(url)
          port = uri.port || (uri.scheme == "https" ? 443 : 80)
          http = Net::HTTP.start(uri.host, port, use_ssl: uri.scheme == "https", verify_mode: OpenSSL::SSL::VERIFY_NONE)

          request = Net::HTTP.const_get(method.capitalize).new(uri.request_uri)
          apply_styles(request, styles)

          http.request(request) do |response|
            handle_response(response, save, styles)
          end
        rescue Net::HTTPError, Net::OpenTimeout, Net::ReadTimeout => e
          handle_error(e, logger)
        rescue StandardError => e
          handle_error(e, logger)
        end
      end
    end

    private

    def apply_styles(request, styles)
      headers = styles[:headers]
      request["Content-Type"] = headers["Content-Type"] if headers && headers["Content-Type"]
      request.body = styles[:body] if styles[:body]
      # ah ig yes add more custom styles to the request as needed
    end

    def handle_response(response, save, styles)
      case response
      when Net::HTTPSuccess
        content = response.body
        headers = extract_headers(response)
        if save
          save_content(content, save)
        else
          handle_finish_event(headers)
        end
      else
        handle_failure(response.code)
      end
    end

    class FileError < StandardError
    end

    def save_content(content, file_name)
      file = nil
      begin
        file = File.open(file_name, "w")
        file.write(content)
      rescue Errno::EACCES, Errno::ENOENT => e
        raise FileError, "File error occurred: #{e.message}"
      else
        # Code to execute when no exceptions or errors occur
        @block&.call
      ensure
        file&.close
      end
    end

    def handle_finish_event(headers)
      @block&.call(headers)
    end

    def extract_headers(response)
      response.each_header.to_h.to_s
    end

    def handle_failure(code)
      logger.error("Failed to download content. Response code: #{code}")
    end

    def handle_error(error, logger)
      logger.error("An error occurred while downloading: #{error.message}")
    end
  end
end
