# frozen_string_literal: true

class Object
  def parent_caller
    caller[0].match(/`(.*)'/)[1]
  end

  def all_callers
    caller.map { |x| x.match(/`(.*)'/)[1] if self.respond_to? x.match(/`(.*)'/)[1].to_sym }.compact
  end

  def caller_key
    caller[0].hash
  end
end

def global_stack
  @global_stack ||= {}
end

class Scarpe
  # STARTING SINGLY, APPENDING TO TOP LEVEL BOX. later will do nested
  class << self
    # Width means nothing right now, but we'll get there
    def stack(width: 1.0)
      hbox = UI.new_horizontal_box
      old_parent = $parent_box ? $parent_box : $vbox
      $parent_box = hbox
      yield
      UI.box_append(old_parent, hbox, 1)
      $parent_box = nil
    end
  end
end
