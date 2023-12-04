# frozen_string_literal: true

class Shoes
  # A Radio button drawable. Only a single radio button may be checked in each
  # group. If no group is specified, or the group is nil, default to all
  # radio buttons in the same slot being treated as being in the same group.
  class Radio < Shoes::Drawable
    shoes_styles :group, :checked
    shoes_events :click

    init_args :group
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
