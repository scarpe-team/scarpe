# frozen_string_literal: true

module Shoes
  # A Radio button widget. Only a single radio button may be checked in each
  # group. If no group is specified, or the group is nil, default to all
  # radio buttons in the same slot being treated as being in the same group.
  class Radio < Shoes::Widget
    display_properties :group, :checked

    def initialize(group = nil, checked = nil, &block)
      @group = group
      @block = block
      super

      bind_self_event("click") { click }
      create_display_widget
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
