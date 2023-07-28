# frozen_string_literal: true

module Shoes
  class Alert < Shoes::Widget
    display_property :text

    def initialize(text)
      @text = text

      super

      bind_self_event("click") do
        remove
      end

      create_display_widget
    end
  end
end
