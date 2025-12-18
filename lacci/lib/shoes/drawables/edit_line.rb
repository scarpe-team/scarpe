# frozen_string_literal: true

class Shoes
  class EditLine < Shoes::Drawable
    shoes_styles :text, :width, :font, :tooltip, :stroke, :secret
    shoes_events :change

    init_args
    opt_init_args :text
    def initialize(*args, **kwargs, &block)
      @block = block
      super

      bind_self_event("change") do |new_text|
        self.text = new_text
        @block&.call(new_text)
      end

      create_display_drawable
    end

    def change(&block)
      @block = block
    end
  end
end
