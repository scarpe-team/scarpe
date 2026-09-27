# frozen_string_literal: true

class Shoes
  class Progress < Shoes::Drawable
    shoes_styles :fraction

    # fraction is a decimal from the start (ledger M5; Shoes 3 gives 0.0)
    Shoes::Drawable.drawable_default_styles[Shoes::Progress][:fraction] = 0.0
    shoes_events # No Progress-specific events yet

    init_args # No positional args
    def initialize(**kwargs)
      super

      create_display_drawable
    end
  end
end
