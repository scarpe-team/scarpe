# frozen_string_literal: true

class Scarpe
  module Hooks
    module State
      def attributes_for_state
        valid_states = ["readonly", "disabled"]

        state = @keywords.delete(:state)

        return unless state

        unless valid_states.include?(state)
          raise ArgumentError,
            "Invalid value \"#{state}\" for :state property on #{self.class}. Allowed values: #{valid_states.join(", ")}"
        end

        # TODO: How does readonly work with a button in original shoes?

        container = {}
        container[:readonly] = "readonly" if state == "readonly"
        container[:disabled] = "disabled" if state == "disabled"

        { container: }
      end
    end
  end
end
