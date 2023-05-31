# frozen_string_literal: true

require "socket"
require "rbconfig"

class Scarpe
  class AppShutdownError < StandardError; end

  module WVRelayUtil # Make sure the including class also includes Scarpe::Log
    def ready_to_read?(timeout = 0.0)
      r, _, e = IO.select [@from], [], [@from, @to].uniq, timeout

      # On timeout, select returns nil instead of arrays.
      return if r.nil?

      unless e.empty?
        raise "#{@i_am}: Got error on connection(s) from IO.select! Dying!"
      end

      !r.empty?
    end

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

    def respond_to_datagram
      message = receive_datagram
      m_data = JSON.parse(message)

      if m_data["type"] == "event"
        kwargs_hash = {}
        m_data["kwargs"].each { |k, v| kwargs_hash[k.to_sym] = v }
        if m_data["kwargs"]["event_type"] == "shoes"
          send_shoes_event(
            *m_data["args"],
            event_name: m_data["kwargs"]["event_name"],
            target: m_data["kwargs"]["event_target"],
            **kwargs_hash,
          )
        elsif m_data["kwargs"]["event_type"] == "display"
          send_display_event(
            *m_data["args"],
            event_name: m_data["kwargs"]["event_name"],
            target: m_data["kwargs"]["event_target"],
            **kwargs_hash,
          )
        else
          @log.error("Unrecognized datagram type:event: #{m_data.inspect}!")
        end
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

  # This "display service" actually creates a child process and sends events
  # back and forth, but creates no widgets of its own.
  class WVRelayDisplayService < Scarpe::DisplayService::Linkable
    include Scarpe::Log
    include WVRelayUtil # Needs Scarpe::Log

    attr_accessor :shutdown

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

      # Subscribe to all event notifications and relay them to the opposite side
      @event_subs << bind_shoes_event(event_name: :any, target: :any) do |*args, **kwargs|
        unless kwargs[:relayed]
          kwargs[:event_type] = :shoes
          kwargs[:relayed] = true
          send_datagram({ type: :event, args:, kwargs: })
        end
      end
      @event_subs << bind_display_event(event_name: :any, target: :any) do |*args, **kwargs|
        unless kwargs[:relayed]
          kwargs[:event_type] = :display
          kwargs[:relayed] = true
          send_datagram({ type: :event, args:, kwargs: })
        end
      rescue AppShutdownError
        @shutdown = true
        @log.info("Attempting to shut down...")
        self.destroy
      end

      # Here, we run our own event loop. We need to poll the connection to the child,
      # and respond appropriately to Ruby calls/callbacks.
      @event_subs << bind_display_event(event_name: "heartbeat") do
        respond_to_datagram while ready_to_read?
      rescue AppShutdownError
        @shutdown = true
        @log.info("Attempting to shut down...")
        self.destroy
      end
    end

    def create_display_widget_for(widget_class_name, widget_id, properties)
      send_datagram({ type: :create, class_name: widget_class_name, id: widget_id, properties: })
      # Don't need to return anything. It wouldn't be used anyway.
    end

    def destroy
      unless @shutdown
        send_datagram({ type: :destroy })
      end
      @shutdown = true
      (@events_subs || []).each { |unsub_id| DisplayService.unsub_from_events(unsub_id) }
    end
  end
end
