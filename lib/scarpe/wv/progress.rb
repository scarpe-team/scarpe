# frozen_string_literal: true

module Scarpe::Webview
  class Progress < Drawable
    def initialize(properties)
      super
    end

    # For now do *not* catch properties_changed and do a small update.
    # Tiranti updates some additional fields (e.g. aria-valuenow) that
    # Calzini does not. We'll want Calzini and Tiranti to handle the
    # updates more for themselves. See issue #419 for updates on how
    # we'll handle this. But for right now we re-render the whole
    # drawable every time we change the progress fraction.
    def element
      render("progress")
    end
  end
end
