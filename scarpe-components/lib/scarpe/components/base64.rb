# frozen_string_literal: true

require "base64"
require "uri"

module Scarpe; end
module Scarpe::Components; end
module Scarpe
  module Components::Base64
    def valid_url?(string)
      uri = URI.parse(string)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError, URI::BadURIError
      false
    end

    def encode_file_to_base64(image_path)
      image_data = File.binread(image_path)

      encoded_data = ::Base64.strict_encode64(image_data)

      encoded_data
    end
  end
end
