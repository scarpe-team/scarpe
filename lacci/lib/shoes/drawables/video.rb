# frozen_string_literal: true

module Shoes
  class Video < Shoes::Drawable
    shoes_styles :url

    def initialize(url)
      super
      @url = url
      create_display_drawable
    end

    # other methods
  end
end
