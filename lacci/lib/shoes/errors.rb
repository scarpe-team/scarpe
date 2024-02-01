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

  class NoSuchLinkableIdError < Shoes::Error; end

  class BadLinkableIdError < Shoes::Error; end

  class UnregisteredShoesError < Shoes::Error; end

  class BadArgumentListError < Shoes::Error; end

  class SingletonError < Shoes::Error; end

  class MultipleShoesSpecRunsError < Shoes::Error; end

  class UnsupportedFeatureError < Shoes::Error; end

  class BadFilenameError < Shoes::Error; end

  class UnknownEventsForClassError < Shoes::Error; end

  class DoubleRegisteredShoesError < Shoes::Error; end
end
