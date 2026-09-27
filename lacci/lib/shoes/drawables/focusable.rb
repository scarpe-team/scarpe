# frozen_string_literal: true

class Shoes
  # Controls that take keyboard focus: text inputs, list boxes, and buttons, checks
  # and radios, which Enter then clicks (manual 2923-2926, 3356-3359; ledger G9).
  module Focusable
    # @return [self]
    def focus
      send_shoes_event({}, event_name: "focus", target: linkable_id)
      self
    end
  end
end
