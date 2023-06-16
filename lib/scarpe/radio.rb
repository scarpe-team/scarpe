# frozen_string_literal: true

class Scarpe
  class Radio < Scarpe::Widget
    display_properties :group

    def initialize(group = nil, &block)
      @group = group
      super
      create_display_widget
    end
  end
end
