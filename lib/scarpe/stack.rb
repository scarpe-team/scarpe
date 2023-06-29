# frozen_string_literal: true

require "net/http"
require "openssl"
require "nokogiri"

class Scarpe
  class Stack < Scarpe::Widget
    include Scarpe::Background
    include Scarpe::Border
    include Scarpe::Spacing

    display_properties :width, :height, :margin, :padding, :scroll, :margin_top, :margin_left, :margin_right, :margin_bottom, :options

    def initialize(width: nil, height: "100%", margin: nil, padding: nil, scroll: false, margin_top: nil, margin_bottom: nil, margin_left: nil,
      margin_right: nil, **options, &block)

      # TODO: what are these options? Are they guaranteed serializable?
      @options = options

      super

      create_display_widget
      # Create the display-side widget *before* instance_eval, which will add child widgets with their display widgets
      instance_eval(&block) if block_given?
    end
  end

  class Widget
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

              get_title(content)
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

    def get_title(content)
      doc = Nokogiri::HTML(content)

      title = doc.at_css("title")&.text&.strip || ""

      # headings = doc.css("h1").map(&:text)

      title
    end
  end
end
