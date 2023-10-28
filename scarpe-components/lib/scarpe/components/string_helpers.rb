# frozen_string_literal: true

module Scarpe; module Components; end; end
module Scarpe::Components::StringHelpers
  # Cut down from Rails camelize
  def self.camelize(string)
    string = string.sub(/^[a-z\d]*/) { |match| match.capitalize }
    string.gsub(/(?:_|(\/))([a-z\d]*)/) { "#{$1}#{$2.capitalize}" }
  end
end
