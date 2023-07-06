# frozen_string_literal: true

require "net/http"
require "openssl"
require "nokogiri"

class Scarpe::Widget
  def download(url)
    Thread.new do
      begin
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        request = Net::HTTP::Get.new(uri.request_uri)

        http.request(request) do |response|
          case response
          when Net::HTTPSuccess
            # content = response.body

            # headers = response.header

            html_get_title(content)
          else
            Scarpe.error("Failed to download content. Response code: #{response.code}")
          end
        end
      rescue StandardError => e
        Scarpe.error("Error occurred while downloading: #{e.message}")
      end
    end
  end

  private

  def html_get_title(content)
    doc = Nokogiri::HTML(content)

    title = doc.at_css("title")&.text&.strip || ""

    # headings = doc.css("h1").map(&:text)

    title
  end
end
