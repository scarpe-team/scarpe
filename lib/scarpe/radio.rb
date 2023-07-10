# frozen_string_literal: true

class Scarpe
  class Radio < Scarpe::Widget
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

    private

    def group_name
      @group || @parent
    end
  end
end
