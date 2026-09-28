# frozen_string_literal: true

class Shoes
  class EditLine < Shoes::Drawable
    include Shoes::Focusable

    shoes_styles :text, :width, :font, :tooltip, :stroke, :secret
    shoes_styles :fill, :border_color # the box and its edge, in the page's colours (ledger G17)
    shoes_style :change # the handler (manual 1123-1128, ledger G10)
    shoes_style :state # nil, "readonly" or "disabled" (manual 1410-1421, ledger G4)
    shoes_events :change, :finish

    # text "returns a string of characters", empty ones included (ledger M5)
    Shoes::Drawable.drawable_default_styles[Shoes::EditLine][:text] = ""

    init_args
    opt_init_args :text
    def initialize(*args, **kwargs, &block)
      @setting_from_event = false
      super
      @change = block if block

      bind_self_event("change") do |new_text|
        @setting_from_event = true
        self.text = new_text
        @setting_from_event = false
        @change&.call(self)
      end

      bind_self_event("finish") do
        @finish&.call(self)
      end

      create_display_drawable
    end

    # Set the change handler.
    #
    # @yield [edit_line] the edit line, already holding its new text (ledger G1)
    # @return [self]
    def change(&block)
      @change = block
      self
    end

    # Run a proc when Return is pressed in the line, so a one-line form can be sent from
    # the keyboard. Shoes 3.2.15 added it (s3t_edit_line.c:15, 42-49; ledger G16).
    #
    # @param handler [Proc, nil] called with the edit line, holding its text
    def finish=(handler)
      @finish = handler
    end

    # Override the auto-generated text= to fire the change callback. Firing change
    # for a programmatic text= is a deliberate Scarpe extension (commit eda8975),
    # pinned as ext-scarpe by the Q7 ruling (ledger G5, 27 Sep 2026).
    def text=(new_value)
      old_value = @text
      new_value = self.class.validate_as("text", new_value)
      @text = new_value
      send_shoes_event({ "text" => new_value }, event_name: "prop_change", target: linkable_id)

      # Fire callback if text changed and not being set from the event handler
      if !@setting_from_event && old_value != new_value
        @change&.call(self)
      end
    end
  end
end
