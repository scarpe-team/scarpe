# frozen_string_literal: true

class Shoes; end
module Shoes::Errors
  class InvalidAttributeValueError < Shoes::Error; end

  class TooManyInstancesError < Shoes::Error; end

  class NoSuchListItemError < Shoes::Error; end

  class DuplicateCreateDrawableError < Shoes::Error; end

  class MultipleDrawablesFoundError < Shoes::Error; end

  class NoDrawablesFoundError < Shoes::Error; end

  class NoSuchStyleError < Shoes::Error; end

  class NoLinkableIdError < Shoes::Error; end

  class BadLinkableIdError < Shoes::Error; end

  class UnregisteredShoesEvent < Shoes::Error; end

  class BadArgumentListError < Shoes::Error; end

  class SingletonError < Shoes::Error; end

  class MultipleShoesSpecRunsError < Shoes::Error; end

  class UnsupportedFeature < Shoes::Error; end
end
