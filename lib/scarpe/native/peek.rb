# frozen_string_literal: true

require "optparse"

module Scarpe::Native
  # `scarpe peek APP.rb [options]`: runs an app headless, performs the steps in the order given,
  # prints what it saw and exits. The quick look-and-click tool for humans and agents (DESIGN 8).
  class Peek
    BANNER = <<~USAGE
      Usage: scarpe peek APP.rb [--size WxH] [--scale 2] [--wait SECS] [--click TEXT | --click-at X,Y]
                                [--drag X,Y,X,Y...] [--type TEXT] [--key NAME] [--wheel DY[,X,Y]]
                                [--window N | --app ID] [--shot OUT.png] [--layout] [--a11y]
      Steps run in the order given. --drag moves to the first point and presses there, moves
      through the rest a frame apart and releases at the last. --window N (counting from 1) or --app ID sends the
      steps after it to that window. --a11y prints what a screen reader meets. With no --shot, no
      --layout and no --a11y, it saves peek.png here.
    USAGE

    # How long a drag rests at each point: a frame of a 24 fps animate block and then some, so
    # an app that reads `mouse` in a timer sees the button down at every point.
    DRAG_STEP = 0.05

    def self.run(argv)
      new(argv).run
    end

    def initialize(argv)
      @origin = Dir.pwd # Shoes.run_app changes directory to the app's
      @steps = []
      @app_path = parse(argv)
      @steps << [:shot, File.join(@origin, "peek.png")] if @steps.none? { |action, _| %i[shot layout a11y].include?(action) }
    end

    def run
      # Registered before the app exists, so it runs after the pump's at_exit and can set the exit status.
      at_exit do
        next if $! # an exception on its way out explains itself

        $stderr.puts("peek: #{@app_path} never started a Shoes app") if Shoes.APPS.empty?
        exit(1) if @failed || Shoes.APPS.empty?
      end
      Scarpe::Native.after_first_heartbeat { perform }
      Shoes.run_app(@app_path)
    end

    private

    def parse(argv)
      parser = OptionParser.new(BANNER) do |opts|
        opts.on("--size WxH") { |size| @size = size.split("x", 2).map { |n| Integer(n) } }
        opts.on("--scale FACTOR", Float) { |scale| @scale = scale }
        opts.on("--wait SECS", Float) { |secs| @steps << [:wait, secs] }
        opts.on("--click TEXT") { |text| @steps << [:click, text] }
        opts.on("--click-at X,Y", Array) { |xy| @steps << [:click_at, xy.map { |n| Float(n) }] }
        opts.on("--drag X,Y,X,Y...", Array) { |xys| @steps << [:drag, drag_points(xys)] }
        opts.on("--type TEXT") { |text| @steps << [:type, text] }
        opts.on("--key NAME") { |name| @steps << [:key, name] }
        opts.on("--wheel DY[,X,Y]", Array) { |values| @steps << [:wheel, values.map { |n| Float(n) }] }
        opts.on("--window N", Integer) { |n| @steps << [:window, n] }
        opts.on("--app ID", Integer) { |id| @steps << [:app, id] }
        opts.on("--shot OUT.png") { |path| @steps << [:shot, File.expand_path(path, @origin)] }
        opts.on("--layout") { @steps << [:layout, nil] }
        opts.on("--a11y") { @steps << [:a11y, nil] }
        opts.on("-h", "--help") { quit_with(BANNER, 0) }
      end
      paths = parser.parse(argv)
      quit_with(BANNER, 1) unless paths.size == 1
      File.expand_path(paths.first, @origin)
    rescue OptionParser::ParseError, ArgumentError => e
      quit_with("#{e.message}\n#{BANNER}", 1)
    end

    def drag_points(values)
      points = values.map { |n| Float(n) }.each_slice(2).to_a
      raise ArgumentError, "--drag needs two or more X,Y points" if points.size < 2 || points.last.size < 2

      points
    end

    def quit_with(message, status)
      (status.zero? ? $stdout : $stderr).puts(message)
      exit(status)
    end

    def perform
      automation.frames(1)
      automation.resize(*@size) if @size
      @steps.each { |action, value| send("do_#{action}", value) }
    rescue StandardError, ScriptError => e # a handler's SyntaxError or LoadError fails the run too
      @failed = true
      $stderr.puts("peek: #{e.is_a?(Scarpe::Error) ? e.message : "#{e.class}: #{e.message}"}")
    ensure
      Shoes.APPS.each(&:destroy)
    end

    def do_wait(seconds)
      automation.advance(seconds)
    end

    def do_click(text)
      report_click("\"#{text}\"", automation.click({ text: text }))
    end

    def do_click_at((x, y))
      report_click("#{x},#{y}", automation.click({ x: x, y: y }))
    end

    def do_drag(points)
      first, *rest = points
      automation.mouse(:move, *first)
      automation.advance(DRAG_STEP)
      automation.mouse(:down, *first)
      rest.each do |x, y|
        automation.advance(DRAG_STEP)
        automation.mouse(:move, x, y)
      end
      automation.advance(DRAG_STEP)
      automation.mouse(:up, *points.last)
      puts "drag #{points.map { |xy| xy.map { |n| number(n) }.join(",") }.join(" -> ")}"
    end

    def do_type(text)
      automation.type(text)
    end

    def do_key(name)
      automation.key(name)
    end

    def do_wheel((dy, x, y))
      automation.wheel(dy, x: x, y: y)
      puts "wheel #{number(dy)}#{" at #{number(x)},#{number(y)}" if x}"
    end

    def do_window(n)
      app = Shoes.APPS[n - 1] if n.positive?
      raise Scarpe::Error, "no window #{n} (#{Shoes.APPS.size} open)" unless app

      aim_at(app)
    end

    def do_app(id)
      app = Shoes.APPS.find { |candidate| candidate.linkable_id == id }
      raise Scarpe::Error, "no app ##{id} (apps: #{Shoes.APPS.map(&:linkable_id).join(", ")})" unless app

      aim_at(app)
    end

    def aim_at(app)
      automation.app = app.linkable_id
      puts "window ##{app.linkable_id} #{app.style[:title].to_s.inspect}"
    end

    def do_shot(path)
      shot = automation.snapshot(path, scale: @scale) || {}
      puts "shot #{shot["path"] || path} (#{shot["w"]}x#{shot["h"]})"
    end

    def do_layout(_)
      automation.layout.each do |node|
        label = node[:text] ? " #{node[:text].inspect}" : ""
        hidden = node[:visible] == false ? " hidden" : ""
        puts "##{node[:id]} #{node[:kind]} #{number(node[:x])},#{number(node[:y])} " \
          "#{number(node[:w])}x#{number(node[:h])}#{hidden}#{label}"
      end
    end

    A11Y_STATES = { selected: "selected", expanded: "open", focused: "focused", disabled: "disabled", read_only: "read-only" }.freeze

    # One line per node a screen reader meets, indented under its parent:
    # `#5 text_input "Name" = "Nick" (focused)`, the name first and then the value.
    def do_a11y(_, node = automation.a11y, depth = 0)
      said = [node[:name]&.inspect, ("= #{node[:value].inspect}" if node[:value])].compact.join(" ")
      state = [{ true => "checked", false => "unchecked" }[node[:toggled]], *A11Y_STATES.filter_map { |key, word| word if node[key] == true }]
      id = "##{node[:id]} " if node[:id] < 2**62 # parts of a drawable (list items, runs of text) have no id of Lacci's
      puts "#{"  " * depth}#{id}#{node[:role]}#{" #{said}" unless said.empty?}#{" (#{state.compact.join(", ")})" if state.compact.any?}"
      Array(node[:children]).each { |child| do_a11y(nil, child, depth + 1) }
    end

    def report_click(target, hit)
      hit ||= {}
      puts "click #{target} -> #{hit["hit"] ? "##{hit["hit"]}" : "nothing"} at #{number(hit["x"])},#{number(hit["y"])}"
    end

    # Rust's f32 coordinates, readable: 79.19999694824219 -> 79.2, 33.0 -> 33.
    def number(value)
      return value.to_s unless value.is_a?(Float)

      rounded = value.round(1)
      rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
    end

    def automation
      DisplayService.instance.automation
    end
  end
end
