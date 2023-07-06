# frozen_string_literal: true

class Scarpe
  class Radio < Scarpe::Widget
    display_properties :group, :checked

    def initialize(group = nil, checked = false, &block)
      @group = group
      @checked = checked
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

    private

    def group_name
      @group || @parent
    end
  end
end
