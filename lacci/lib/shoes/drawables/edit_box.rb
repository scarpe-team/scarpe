# frozen_string_literal: true

class Shoes
  class EditBox < Shoes::Drawable
    shoes_styles :text, :height, :width, :tooltip, :font, :stroke
    shoes_events :change

    init_args
    opt_init_args :text
    def initialize(*args, **kwargs, &block)
      @callback = block
      @setting_from_event = false
      super

      bind_self_event("change") do |new_text|
        @setting_from_event = true
        self.text = new_text
        @setting_from_event = false
        @callback&.call(self)
      end

      create_display_drawable
    end

    def change(&block)
      @callback = block
    end

    # Override the auto-generated text= to fire the change callback
    def text=(new_value)
      old_value = @text
      new_value = self.class.validate_as("text", new_value)
      @text = new_value
      send_shoes_event({ "text" => new_value }, event_name: "prop_change", target: linkable_id)

      # Fire callback if text changed and not being set from the event handler
      if !@setting_from_event && old_value != new_value
        @callback&.call(self)
      end
    end

    def append(new_text)
      self.text = (self.text || "") + new_text
    end

    # Set keyboard focus to this text area.
    # @return [self]
    def focus
      send_shoes_event({}, event_name: "focus", target: linkable_id)
      self
    end
  end
end
