# frozen_string_literal: true

class Shoes
  class Check < Shoes::Drawable
    shoes_styles :checked
    shoes_events :click

    init_args
    opt_init_args :checked
    def initialize(*args, **kwargs, &block)
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
