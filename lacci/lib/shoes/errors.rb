# frozen_string_literal: true

module Shoes
  class InvalidAttributeValueError < Shoes::Error; end

  class TooManyInstancesError < Shoes::Error; end

  class NoSuchStyleError < Shoes::Error; end

  class NoLinkableIdError < Shoes::Error; end
end
