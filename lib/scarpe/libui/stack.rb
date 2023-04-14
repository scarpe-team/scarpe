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
      if top_level?
        global_stack[caller_key] = hbox
        UI.window_set_child($vbox, hbox)
      else
        # global_stack[something][all][the][way][down] = hbox
        # UI.box_append(global_stack[something][all][the][way], hbox, 0)
      end
      @box_present = hbox
      yield
    end

    private

    # Later we'll check for parent, but for now, just top level
    def top_level?
      true
    end
  end
end
