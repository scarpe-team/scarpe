# frozen_string_literal: true

class Shoes
  # A native visual transition. Cancellation keeps its last sampled values and
  # suppresses completion. The display service settles it before calling user code.
  class Transition
    def initialize(cancel:, complete:)
      @cancel = cancel
      @complete = complete
      @active = true
    end

    def active?
      @active
    end

    def cancel
      @cancel&.call
      self
    end

    # Display-service lifecycle hook, not an application operation.
    def __finish(completed)
      return unless @active

      @active = false
      callback = @complete
      @cancel = @complete = nil
      callback&.call if completed
    end
  end
end
