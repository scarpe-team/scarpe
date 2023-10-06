# frozen_string_literal: true

module Shoes
  class Check < Shoes::Drawable
    display_properties :checked

    def initialize(checked = nil, &block)
      @block = block
      super

      bind_self_event("click") { click }
      create_display_drawable
    end

    def click(&block)
      @block = block
      self.checked = !checked?
    end

    def checked?
      @checked ? true : false
    end

    def checked(value)
      self.checked = value
    end
  end
end
