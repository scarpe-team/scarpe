# frozen_string_literal: true

class Scarpe
  class Video < Scarpe::Widget
    display_properties :url

    def initialize(url)
      @url = url
      super
      create_display_widget
    end

    # other methods
  end
end
