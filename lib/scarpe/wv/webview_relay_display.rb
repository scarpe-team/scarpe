# frozen_string_literal: true

require "socket"
require "rbconfig"

class Scarpe
  # An error occurred which would normally be handled by shutting down the app
  class AppShutdownError < Scarpe::Error; end

  # WVRelayUtil defines the datagram format for the sockets that connect a parent
  # Shoes application with a child display server.
  #
  # The class including this module should also include Shoes::Log so that it can
  # be used.
  module WVRelayUtil
    # Checks whether the internal socket is ready to be read from.
    # If timeout is greater than 0, this will block for up to that long.
    #
    # @param timeout [Float] the longest to wait for more input to read
    # @return [Boolean] whether the socket has data ready for reading
    def ready_to_read?(timeout = 0.0)
      r, _, e = IO.select [@from], [], [@from, @to].uniq, timeout

      # On timeout, select returns nil instead of arrays.
      return if r.nil?

      unless e.empty?
        raise "#{@i_am}: Got error on connection(s) from IO.select! Dying!"
      end

      !r.empty?
    end

    # Send bytes on the internal socket to the opposite side.
    #
    # @param contents [String] data to send
    # @return [void]
    def send_datagram(contents)
      str_data = JSON.dump contents
      dgram_str = (str_data.length.to_s + "a" + str_data).encode(Encoding::BINARY)
      to_write = dgram_str.bytesize
      written = 0

      until written == to_write
        count = @to.write(dgram_str.byteslice(written..-1))
        if count.nil? || count == 0
          raise "Something was wrong in send_datagram! Write returned #{count.inspect}!"
        end

        written += count
      end

      nil
    end

    # Read data from the internal socket. Read until a whole datagram
    # has been received and then return it.
    #
    # @return [String] the received datagram
    def receive_datagram
      @readbuf ||= String.new.encode(Encoding::BINARY)
      to_read = nil

      loop do
        # Have we read a packet length already, sitting in @readbuf?
        a_idx = @readbuf.index("a")
        if a_idx
          to_read = @readbuf[0..a_idx].to_i
          @readbuf = @readbuf[(a_idx + 1)..-1]
          break
        end

        # If not, read more bytes
        new_bytes = @from.read(10)
        if new_bytes.nil?
          # This is perfectly normal, if the connection closed
          raise AppShutdownError, "Got an unexpected EOF reading datagram! " +
            "Did the #{@i_am == :child ? "parent" : "child"} process die?"
        end
        @readbuf << new_bytes
      end

      loop do
        if @readbuf.bytesize >= to_read
          out = @readbuf.byteslice(0, to_read)
          @readbuf = @readbuf.byteslice(to_read, -1)
          return out
        end

        new_bytes = @from.read(to_read - @readbuf.bytesize)
        @readbuf << new_bytes
      end
    rescue
      raise AppShutdownError, "Got exception #{$!.class} when receiving datagram... #{$!.inspect}"
    end

    # Read a datagram from the internal buffer and then dispatch it to the
    # appropriate handler.
    def respond_to_datagram
      message = receive_datagram
      m_data = JSON.parse(message)

      if m_data["type"] == "event"
        kwargs_hash = {}
        m_data["kwargs"].each { |k, v| kwargs_hash[k.to_sym] = v }
        send_shoes_event(
          *m_data["args"],
          event_name: m_data["kwargs"]["event_name"],
          target: m_data["kwargs"]["event_target"],
          **kwargs_hash,
        )
      elsif m_data["type"] == "create"
        raise "Parent process should never receive :create datagram!" if @i_am == :parent

        @wv_display.create_display_widget_for(m_data["class_name"], m_data["id"], m_data["properties"])
      elsif m_data["type"] == "destroy"
        if @i_am == :parent
          @shutdown = true
        else
          @log.info("Shutting down...")
          exit 0
        end
      else
        @log.error("Unrecognized datagram type:event: #{m_data.inspect}!")
      end
    end

    # Loop for up to `t` seconds, reading data and waiting.
    #
    # @param t [Float] the number of seconds to loop for
    def event_loop_for(t = 1.5)
      t_start = Time.now
      delay_time = t

      while Time.now - t_start < delay_time
        if ready_to_read?(0.1)
          respond_to_datagram
        else
          sleep 0.1
        end
      end
    end
  end

  # This display service creates a child process and sends events
  # back and forth, but creates no widgets of its own. The child
  # process will spawn a worker with its own WebviewDisplayService
  # where the real Webview exists. By splitting the Webview
  # process from the Shoes widgets, it can be easier to return
  # control to Webview's event handler promptly. Also, the Ruby
  # process could run background threads if it wanted, and
  # otherwise behave like a process ***not*** containing Webview.
  class WVRelayDisplayService < Shoes::DisplayService
    include Shoes::Log
    include WVRelayUtil # Needs Shoes::Log

    attr_accessor :shutdown

    # Create a Webview Relay Display Service
    def initialize
      super()
      log_init("WV::RelayDisplayService")

      @event_subs = []
      @shutdown = false
      @i_am = :parent

      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]

      @pid = spawn(RbConfig.ruby, File.join(__dir__, "wv_display_worker.rb"), port.to_s)
      @from = @to = server.accept

      # Subscribe to all event notifications and relay them to the worker
      @event_subs << bind_shoes_event(event_name: :any, target: :any) do |*args, **kwargs|
        unless kwargs[:relayed]
          kwargs[:relayed] = true
          send_datagram({ type: :event, args:, kwargs: })
        end

        # Forward the run event to the child process before doing this
        if event_name == "run"
          run_event_loop
        end
      rescue AppShutdownError
        @shutdown = true
        @log.info("Attempting to shut down...")
        self.destroy
      end
    end

    # Run, sending and responding to datagrams continuously.
    def run_event_loop
      until @shutdown
        respond_to_datagram while ready_to_read?
        sleep 0.1
      end
    rescue AppShutdownError
      @shutdown = true
      @log.info("Attempting to shut down...")
      self.destroy
    end

    # This method sends a message to the worker process to create a widget. No actual
    # widget is created or registered with the display service.
    def create_display_widget_for(widget_class_name, widget_id, properties)
      send_datagram({ type: :create, class_name: widget_class_name, id: widget_id, properties: })
      # Don't need to return anything. It wouldn't be used anyway.
    end

    # Tell the worker process to quit, and set a flag telling the event loop to shut down.
    def destroy
      unless @shutdown
        send_datagram({ type: :destroy })
      end
      @shutdown = true
      (@events_subs || []).each { |unsub_id| DisplayService.unsub_from_events(unsub_id) }
    end
  end
end
