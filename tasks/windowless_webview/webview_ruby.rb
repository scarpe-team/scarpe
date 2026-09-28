# frozen_string_literal: true

# A stand-in for the webview_ruby gem that opens no window and runs no JavaScript. With this
# directory first on the load path (WINDOWLESS=1 does that for the HTML fixture tasks),
# `require "webview_ruby"` loads this file instead, and the gem's native library never loads.
#
# Scarpe drives it as it drives a real webview, and the page it builds is the same HTML. Of the
# page's scripts, only the ones that call straight back into Ruby are played: a call such as
# `scarpeInit();` reaches its binding once the page has "loaded", and setInterval or setTimeout
# on a binding fire on the clock. No eval runs, so none is ever answered.
module WebviewRuby
  WINDOWLESS = true

  class Webview
    attr_reader :is_running

    def initialize(debug: false)
      @is_running = false
      @bindings = {}
      @scripts = []
      @timers = [] # [due, interval or nil, binding name]
    end

    def set_title(_title) = nil
    def set_size(_width, _height, _hint = 0) = nil
    def navigate(_page) = nil
    def eval(_js) = nil
    def destroy = nil

    def bind(name, &block)
      @bindings[name] = block
      nil
    end

    def init(js)
      @scripts << js.strip
      nil
    end

    # Plays the page's scripts, then fires their timers until terminate.
    def run
      @is_running = true
      @scripts.each do |js|
        case js
        when /\A(\w+)\(\);?\z/ then call(Regexp.last_match(1))
        when /\AsetInterval\((\w+),\s*(\d+)\);?\z/ then schedule(Regexp.last_match(1), Regexp.last_match(2), repeat: true)
        when /\AsetTimeout\((\w+),\s*(\d+)\);?\z/ then schedule(Regexp.last_match(1), Regexp.last_match(2), repeat: false)
        end
      end
      until !@is_running || @timers.empty?
        due, interval, name = @timers.delete_at(@timers.each_index.min_by { |i| @timers[i].first })
        wait = due - monotonic
        sleep(wait) if wait.positive?
        @timers << [[due + interval, monotonic].max, interval, name] if interval
        call(name)
      end
    end

    def terminate
      @is_running = false
      nil
    end

    private

    def schedule(name, milliseconds, repeat:)
      seconds = milliseconds.to_i / 1000.0
      @timers << [monotonic + seconds, (seconds if repeat), name] if @bindings.key?(name)
    end

    # As in the gem, a binding that raises ends the run.
    def call(name)
      block = @bindings[name] or return
      block.call
    rescue StandardError => e
      warn("#{e.full_message}\nThe #{name} binding raised, so the webview stand-in stops.")
      terminate
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
