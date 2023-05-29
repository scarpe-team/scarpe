# frozen_string_literal: true

require "net/http"
require "openssl"
require "nokogiri"

class Scarpe
  class Stack < Scarpe::Widget
    include Scarpe::Background
    include Scarpe::Border
    include Scarpe::Spacing

    display_properties :width, :height, :margin, :padding, :scroll, :options

    def initialize(width: nil, height: nil, margin: nil, padding: nil, scroll: false, **options, &block)
      # TODO: what are these options? Are they guaranteed serializable?
      @options = options

      super

      create_display_widget
      # Create the display-side widget *before* instance_eval, which will add child widgets with their display widgets

      instance_eval(&block)
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
              content = response.body

              puts "Content is:\n#{content}"

              headers = response.header

              puts "Headers are:\n#{headers.inspect}"

              get_title(content)
            else
              puts "Failed to download content. Response code: #{response.code}"
            end
          end
        rescue StandardError => e
          puts "Error occurred while downloading: #{e.message}"
        end
      end
    end

    private

    def get_title(content)
      doc = Nokogiri::HTML(content)
      title = doc.at_css("title")&.text&.strip || ""
      puts "\ntitle: #{title}"

      headings = doc.css("h1").map(&:text)
      puts "\nheadings: #{headings}"

      title
    end
  end
end
