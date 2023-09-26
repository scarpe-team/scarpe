# frozen_string_literal: true

module Shoes
  class Video < Shoes::Widget
    display_properties :url

    def initialize(url)
      super
      @url = url
      create_display_widget
    end

    # other methods
  end
end
