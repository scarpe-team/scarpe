# frozen_string_literal: true

class Shoes
  class EditBox < Shoes::Drawable
    shoes_styles :text, :height, :width ,:tooltip, :font
    shoes_events :change

    init_args
    opt_init_args :text
    def initialize(*args, **kwargs, &block)
      @callback = block
      super

      bind_self_event("change") do |new_text|
        self.text = new_text
        @callback&.call(self)
      end

      create_display_drawable
    end

    def change(&block)
      @callback = block
    end

    def append(new_text)
      self.text = (self.text || "") + new_text
    end
  end
end
