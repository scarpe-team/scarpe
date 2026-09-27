# frozen_string_literal: true

class Shoes
  class Check < Shoes::Drawable
    include Shoes::Focusable

    shoes_styles :checked
    shoes_style :state # nil, "readonly" or "disabled" (manual 1410-1421, ledger G4)
    shoes_events :click

    init_args
    opt_init_args :checked
    def initialize(*args, **kwargs, &block)
      super
      @click = block if block

      bind_self_event("click") do
        self.checked = !checked?
        @click&.call(self)
      end
      create_display_drawable
    end

    # @yield [check] the check box, already toggled
    # @return [self]
    def click(&block)
      @click = block
      self
    end

    def checked?
      @checked ? true : false
    end

    def checked(value)
      self.checked = value
    end
  end
end
