#!/usr/bin/env ruby
# frozen_string_literal: true

require "socket"

# Wherever this file is installed, locate Scarpe relative to it. This could be an installed gem or a dev repo.
SCARPE_DIR = File.join(__dir__, "../..")

$LOAD_PATH.prepend(SCARPE_DIR)
require "scarpe"
require "scarpe/wv_local"

# This script exists to create a WebviewDisplayService that can be operated remotely over a socket.

if ARGV.length != 1
  $stderr.puts("Usage: wv_display_worker.rb tcp_port_num")
  exit(-1)
end

# This is the implementation of a freestanding Scarpe Webview display server,
# which connects via sockets and sends events and properties back and forth
# with a display-less Shoes app. The interface is designed to allow fork-based
# usage, where a parent process could create a paired sockets and start the
# child server. It can also be used via TCP sockets or similar, where a single
# socket is both input and output.
class WebviewContainedService < Shoes::Linkable
  include Scarpe::Log
  include Scarpe::WVRelayUtil # Needs Scarpe::Log

  attr_reader :log

  # Create a new DisplayService.
  #
  # @param from [Socket] a readable socket to get input from the Shoes process
  # @param to [Socket] a writable socket on which to send output to the Shoes process
  def initialize(from, to)
    super()
    log_init("WV::DisplayWorker")

    @i_am = :child
    @event_subs = []
    @wv_display = Scarpe::WebviewDisplayService.new

    @from = from
    @to = to

    @init_done = false

    # Wait to register our periodic_code until the wrangler exists
    @event_subs << bind_shoes_event(event_name: "init") do
      @wv_display.wrangler.periodic_code("datagramProcessor", 0.1) do
        respond_to_datagram while ready_to_read?(0.0)
      end
      @init_done = true
    end

    # Subscribe to all event notifications and relay them to the opposite side
    @event_subs << bind_shoes_event(event_name: :any, target: :any) do |*args, **kwargs|
      unless kwargs[:relayed] || kwargs["relayed"]
        kwargs[:relayed] = true
        send_datagram({ type: :event, args:, kwargs: })
      end
    end

    # Run for 2.5 seconds to let the app be created and "run" to get called.
    # Once that happens, Webview will take over the event loop.
    event_loop_for(2.5)
  end
end

s = TCPSocket.new("localhost", ARGV[0].to_i)

SERVICE = WebviewContainedService.new(s, s)

SERVICE.log.info("Finished event loop. Exiting!")
