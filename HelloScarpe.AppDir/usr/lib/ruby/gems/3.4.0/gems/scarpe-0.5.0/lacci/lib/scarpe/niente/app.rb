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
      send_shoes_event("return", event_name: "custom_event_loop")

      @do_shutdown = false
      bind_shoes_event(event_name: "destroy") do
        @do_shutdown = true
      end

      at_exit do
        until @do_shutdown
          Shoes::DisplayService.dispatch_event("heartbeat", nil)
        end
      end
    end

    def destroy
    end
  end
end
