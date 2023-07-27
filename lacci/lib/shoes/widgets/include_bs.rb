# frozen_string_literal: true

module Shoes
  class IncludeBs < Shoes::Widget
    def initialize(*args, **html_attributes)
      @html_attributes = html_attributes || {}
      super

      create_display_widget
    end
  end
end
