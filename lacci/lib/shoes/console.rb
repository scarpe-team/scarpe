# frozen_string_literal: true

class Shoes
  # The Shoes console (manual 719-844): what the program said with debug, info and error, the
  # errors its handlers, timers and startup raised, and the display's own warnings, newest
  # first. Alt-/ opens it (Cmd-/ on a Mac, which arrives as :alt_/, ledger Q5), and so does
  # Shoes.show_console, in a window of its own, as Shoes 3's Shoes.show_log did (ledger K8). It
  # never opens by itself.
  #
  # Anything may add a line, from any thread and even a signal trap: lines wait in a queue,
  # and the window draws them on the event loop.
  class Console
    TITLE = "Shoes Console"
    # Lines kept, and lines one open window shows; the oldest go first.
    LIMIT = 500
    # How many backtrace lines an error shows under its message: the program's own, where it
    # has any, else Scarpe's.
    TRACE_LINES = 5

    Entry = Struct.new(:seq, :level, :message, :at, :where, :trace, keyword_init: true)

    LEVELS = {
      debug: ["Debug", "#777777"],
      info: ["Info", "#0055cc"],
      warn: ["Warning", "#b36b00"],
      error: ["Error", "#c0392b"],
      fatal: ["Error", "#c0392b"],
    }.freeze

    @incoming = Thread::Queue.new
    @entries = []
    @lock = Mutex.new
    @seq = 0

    class << self
      # Adds a line: level is :debug, :info, :warn or :error.
      #
      # @param where [String, nil] the file and line it came from, in words
      # @param trace [Array<String>, nil] the backtrace, for an error
      # @return [nil]
      def log(level, message, where: nil, trace: nil)
        level = level.to_s.downcase.to_sym
        level = :info unless LEVELS.key?(level)
        @incoming << Entry.new(level: level, message: message.to_s, at: Time.now, where: where, trace: trace)
        # Nobody may look for a long while: the oldest waiting lines go, as kept lines do.
        @incoming.pop(true) while @incoming.size > LIMIT
        nil
      rescue ThreadError
        nil
      end

      # Adds an error from Shoes::ErrorReport (a Hash with String keys).
      def report(err)
        place = err["path"] && [File.basename(err["path"].to_s), ("line #{err["line"]}" if err["line"])].compact.join(", ")
        where = [DURING[err["during"]], place].compact.join(", ")
        log(:error, "#{err["class"]}: #{err["message"]}", where: where.empty? ? nil : where, trace: err["backtrace"])
      end

      # Adds an exception the program handed to error itself, with where it came from.
      def exception(error)
        report(Shoes::ErrorReport.from(error, during: "handler").merge("during" => nil))
      end

      # Every line kept, oldest first.
      def entries
        @lock.synchronize do
          until @incoming.empty?
            entry = @incoming.pop
            entry.seq = (@seq += 1)
            @entries << entry
          end
          @entries.shift(@entries.size - LIMIT) if @entries.size > LIMIT
          @entries.dup
        end
      end

      def clear!
        entries
        @lock.synchronize { @entries.clear }
        nil
      end

      # Opens the console beside the app that asked, or as the app when none is running, or
      # hands back the one already open.
      #
      # @return [Shoes::App] the console's window
      def show
        return @window if @window && Shoes.APPS.include?(@window)

        draw = proc { Shoes::Console.new(self).draw }
        styles = { title: TITLE, width: 600, height: 420 }
        opener = Shoes.APPS.last
        @window = opener ? opener.window(**styles, &draw) : Shoes.app(**styles, &draw)
      end

      # The console window, while it is open.
      def window
        @window if @window && Shoes.APPS.include?(@window)
      end
    end

    # "during" in words, as the console says where an error happened.
    DURING = {
      "startup" => "while the program started",
      "handler" => "in a handler",
      "timer" => "in a timer",
      "exit" => "while the program ended",
    }.freeze

    def initialize(app)
      @app = app
      @shown = 0
    end

    # The Shoes calls below are the app's: the blocks here keep this object as self (ledger B1).
    def method_missing(name, *args, **kwargs, &block)
      return super unless @app.respond_to?(name)

      @app.public_send(name, *args, **kwargs, &block)
    end

    def respond_to_missing?(name, include_private = false)
      @app.respond_to?(name) || super
    end

    def draw
      background white
      flow do
        background "#1d1d1f"
        stack(width: -110) { tagline TITLE, stroke: white, size: 16, margin: [14, 10, 8, 10] }
        button("Clear", width: 90, margin: [8, 10, 12, 8]) { clear_all }
      end
      @quiet = para "Nothing to show yet. What your program says with debug, info and error " \
        "comes here, and so does any error it runs into.", size: 11, stroke: "#777777", margin: [14, 14, 14, 8]
      @list = stack
      refresh
      every(0.25) { refresh }
    end

    # Puts every line that came since the last look at the top of the list.
    def refresh
      fresh = Console.entries.select { |entry| entry.seq > @shown }
      return if fresh.empty?

      @shown = fresh.last.seq
      @quiet.hide
      fresh.each { |entry| @list.prepend { line(entry) } }
      @list.contents.drop(LIMIT).each(&:remove)
    end

    private

    def clear_all
      Console.clear!
      @list.clear
      @quiet.show
    end

    # The frames in the program's own files, paths shortened to the directory it runs in.
    def trace_lines(trace)
      frames = Array(trace).map(&:to_s)
      own = frames.reject { |frame| Shoes::ErrorReport.library?(frame[/\A(.+?):\d+/, 1]) }
      here = "#{Dir.pwd}/"
      (own.empty? ? frames.first(3) : own.first(TRACE_LINES)).map { |frame| frame.delete_prefix(here) }
    end

    def line(entry)
      label, colour = LEVELS[entry.level]
      stack margin: [10, 6, 10, 0] do
        background(entry.level == :error || entry.level == :fatal ? "#fbeeec" : "#f1f5e1", curve: 4)
        heading = [strong(label, stroke: colour), "  ", span(entry.at.strftime("%H:%M:%S"), stroke: "#999999")]
        heading += ["  ", span(entry.where, stroke: "#228899")] if entry.where && !entry.where.empty?
        para(*heading, size: 9, margin: [10, 6, 10, 0])
        trace = trace_lines(entry.trace)
        para entry.message, size: 11, margin: [10, 2, 10, trace.empty? ? 8 : 2]
        para trace.join("\n"), size: 9, family: "monospace", stroke: "#666666", margin: [10, 0, 10, 8] unless trace.empty?
      end
    end
  end
end
