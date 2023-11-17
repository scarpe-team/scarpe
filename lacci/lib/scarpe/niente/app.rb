# frozen_string_literal: true

module Niente
  class App < Drawable
    def initialize(properties)
      super

      bind_shoes_event(event_name: "init") { init }
      bind_shoes_event(event_name: "run") { run }
      bind_shoes_event(event_name: "destroy") { destroy }
    end

    def init
    end

    def run
      send_shoes_event("wait", event_name: "custom_event_loop")
    end

    def destroy
    end
  end
end
