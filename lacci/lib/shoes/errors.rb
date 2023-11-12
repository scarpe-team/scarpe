# frozen_string_literal: true

class Shoes
  class InvalidAttributeValueError < Shoes::Error; end

  class TooManyInstancesError < Shoes::Error; end

  class NoSuchListItemError < Shoes::Error; end

  class DuplicateCreateDrawableError < Shoes::Error; end

  class NoSuchStyleError < Shoes::Error; end

  class NoLinkableIdError < Shoes::Error; end

  class BadLinkableIdError < Shoes::Error; end

  class UnregisteredShoesEvent < Shoes::Error; end
end
