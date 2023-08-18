# frozen_string_literal: true

class Scarpe
  # STARTING SINGLY, APPENDING TO TOP LEVEL BOX. later will do nested
  class << self
    # Width means nothing right now, but we'll get there
    def flow(width: 1.0)
      vertbox = UI.new_vertical_box
      old_parent = $parent_box ? $parent_box : $vbox
      $parent_box = vertbox
      yield
      UI.box_append(old_parent, vertbox, 1)
      $parent_box = nil
    end
  end
end
