#!/usr/bin/env ruby
# frozen_string_literal: true

# A stand-in for native/target/release/scarpe-native that speaks protocol v1 (native/DESIGN.md
# section 4) well enough to test the Ruby shim end to end. Point SCARPE_NATIVE_BIN at it.
#
#   FAKE_CHILD_LOG=path     appends every message it receives, one JSON object per line
#   FAKE_CHILD_ARGV=path    writes the arguments it was started with, as a JSON array
#   FAKE_CHILD_PID=path     writes its pid
#   FAKE_CHILD_SCRIPT=path  a JSON array of rules, each fired the first time its "on" matches:
#     "on":    a message type ("run", "props", ...) or "req:<op>" ("req:click", "req:dialog")
#     "match": fields the message must have, e.g. {"kind": "Button"}
#     "emit":  messages to write. A "target" or "id" of {"kind": K} or {"text": T} becomes that node's id;
#              an "app" of "first" becomes the first running app, and "each" one message per app.
#              For a req they go before the reply.
#     "reply": the value to answer a req with, instead of the canned one
#     "after": seconds to wait before emitting
#     "crash": text to print to stderr before dying with status 101
#     "signal_parent": a signal name to send the Ruby process (what Ctrl-C in a terminal does)
#     "exit":  a status to exit with right after emitting
#     "hang":  true to stop reading for good, like a renderer stuck in layout (signals still end it)
#
# Layout is fake: every visible node gets a 100x20 box, one per row, in tree order.

require "json"
require "zlib"

class FakeChild
  ROW = 20
  CLICKABLE = %w[Button Check Radio Image Link].freeze
  EDITABLE = %w[EditLine EditBox].freeze
  DIALOG_ANSWERS = {
    "alert" => nil, "confirm" => true, "ask" => "fake answer", "ask_color" => [1, 2, 3, 255],
    "ask_open_file" => "/tmp/fake-open", "ask_save_file" => "/tmp/fake-save",
    "ask_open_folder" => "/tmp/fake-folder", "ask_save_folder" => "/tmp/fake-folder"
  }.freeze
  # A 1x1 white PNG, so a snapshot leaves a real image file behind.
  PNG = begin
    chunk = ->(type, data) { [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N") }
    "\x89PNG\r\n\x1a\n".b + chunk.call("IHDR", [1, 1, 8, 6, 0, 0, 0].pack("NNCCCCC")) +
      chunk.call("IDAT", Zlib::Deflate.deflate("\x00\xff\xff\xff\xff".b)) + chunk.call("IEND", "")
  end

  Node = Struct.new(:id, :kind, :parent, :props, :children)

  def initialize
    File.write(ENV["FAKE_CHILD_ARGV"], JSON.generate(ARGV)) if ENV["FAKE_CHILD_ARGV"]
    File.write(ENV["FAKE_CHILD_PID"], Process.pid.to_s) if ENV["FAKE_CHILD_PID"]
    @log = ENV["FAKE_CHILD_LOG"] && File.open(ENV["FAKE_CHILD_LOG"], "a")
    @rules = ENV["FAKE_CHILD_SCRIPT"] ? JSON.parse(File.read(ENV["FAKE_CHILD_SCRIPT"])) : []
    @nodes = {}
    @order = []
    @apps = []
    @scheduled = []
    @focused = nil
    @hovered = nil
    $stdout.sync = true
  end

  def run
    buffer = String.new
    loop do
      ready = IO.select([$stdin], nil, nil, next_timeout)
      emit_scheduled
      next unless ready

      chunk = $stdin.read_nonblock(65_536, exception: false)
      next if chunk == :wait_readable
      break if chunk.nil? # our parent has gone

      buffer << chunk
      while (newline = buffer.index("\n"))
        handle(JSON.parse(buffer.slice!(0..newline)))
      end
    end
  end

  private

  def handle(message)
    @log&.puts(JSON.generate(message))
    @log&.flush
    key = message["t"] == "req" ? "req:#{message["op"]}" : message["t"]
    rules = take_rules(key, message)
    crash(rules.find { |rule| rule["crash"] })
    rules.each { |rule| Process.kill(rule["signal_parent"], Process.ppid) if rule["signal_parent"] }

    if message["t"] == "req"
      rules.each { |rule| emit_rule(rule) }
      answer = rules.find { |rule| rule.key?("reply") }
      reply(message, answer)
    else
      apply(message)
      rules.each { |rule| emit_rule(rule) }
    end
    rules.each { |rule| exit(rule["exit"]) if rule.key?("exit") }
    sleep if rules.any? { |rule| rule["hang"] }
  end

  def apply(message)
    case message["t"]
    when "hello" then write(t: "ready", v: 1, version: "fake")
    when "create" then create(message)
    when "props" then @nodes[message["id"]]&.props&.merge!(message["props"])
    when "destroy" then destroy(message["id"])
    when "reparent" then reparent(message)
    when "run" then @apps << message["app"] unless @apps.include?(message["app"])
    when "focus" then @focused = message["id"]
    when "quit" then quit(message["app"])
    end
  end

  def create(message)
    node = Node.new(message["id"], message["kind"], message["parent"], message["props"] || {}, [])
    @nodes[node.id] = node
    @order << node.id
    parent = @nodes[message["parent"]]
    return unless parent

    index = message["index"]
    index ? parent.children.insert(index, node.id) : parent.children << node.id
  end

  def destroy(id)
    node = @nodes.delete(id) or return
    @order.delete(id)
    @nodes[node.parent]&.children&.delete(id)
    node.children.dup.each { |child| destroy(child) }
  end

  def reparent(message)
    node = @nodes[message["id"]] or return
    @nodes[node.parent]&.children&.delete(node.id)
    node.parent = message["parent"]
    siblings = @nodes[node.parent]&.children or return
    message["index"] ? siblings.insert(message["index"], node.id) : siblings << node.id
  end

  def quit(app)
    app ? @apps.delete(app) : @apps.clear
    exit(0) if @apps.empty?
  end

  # Requests

  def reply(message, rule)
    value, error = rule ? [rule["reply"], nil] : answer(message)
    extras = message["op"] == "dialog" ? { cancelled: false } : {}
    write(t: "reply", req: message["req"], value: value, error: error, **extras)
  end

  def answer(message)
    case message["op"]
    when "ping" then ["pong"]
    when "frames" then [nil]
    when "layout" then [layout]
    when "click" then click(message)
    when "mouse" then [mouse(message)]
    when "type" then [type(message["text"])]
    when "key" then [send_to_items("keypress", [wire_key(message["key"])])]
    when "wheel" then [send_to_items("wheel", [message["dy"], message["x"], message["y"]])]
    when "snapshot" then [snapshot(message["path"])]
    when "pixel" then [[255, 255, 255, 255]]
    when "focused" then [@focused]
    when "resize" then [resize(message)]
    when "dialog" then [DIALOG_ANSWERS[message["kind"]]]
    when "clipboard" then [clipboard(message)]
    else [nil, "unknown op #{message["op"]}"]
    end
  end

  # The clipboard req: with text it sets the clipboard, without it reads it.
  def clipboard(message)
    return @clipboard.to_s unless message.key?("text")

    @clipboard = message["text"]
    nil
  end

  def layout
    boxed.each_with_index.map do |node, row|
      entry = { id: node.id, kind: node.kind, x: 0, y: row * ROW, w: 100, h: ROW, visible: true }
      text = text_of(node)
      text ? entry.merge(text: text) : entry
    end
  end

  # Visible nodes in paint order: each app's tree, depth first, children in their stored order.
  def boxed
    roots = @order.map { |id| @nodes[id] }.select { |node| node.kind == "DocumentRoot" }
    roots.flat_map { |root| descendants(root) }.reject do |node|
      node.kind == "SubscriptionItem" || node.props["hidden"]
    end
  end

  def descendants(node)
    node.children.map { |id| @nodes[id] }.compact.flat_map { |child| [child, *descendants(child)] }
  end

  def click(message)
    target = message["target"] || {}
    node = if target["id"] then @nodes[target["id"]]
    elsif target["text"] then @nodes.values.find { |n| text_of(n) == target["text"] }
    else node_at(target["x"], target["y"])
    end
    return [{ hit: nil }, "nothing to click at #{target.inspect}"] unless node && boxed.include?(node)

    x, y = center_of(node)
    @focused = node.id if EDITABLE.include?(node.kind)
    if CLICKABLE.include?(node.kind)
      event("click", node.id, [])
    elsif node.props["has_click"]
      event("click", node.id, [message["button"] || 1, x, y])
    end
    [{ hit: node.id, x: x, y: y }]
  end

  def mouse(message)
    x = message["x"]
    y = message["y"]
    write(t: "mouse", state: [message["action"] == "down" ? 1 : 0, x, y])
    return unless message["action"] == "move"

    under = node_at(x, y)&.id
    return if under == @hovered

    event("leave", @hovered, []) if @hovered
    event("hover", under, []) if under
    @hovered = under
  end

  def type(text)
    node = @nodes[@focused]
    return unless node && EDITABLE.include?(node.kind)

    event("change", node.id, [node.props["text"].to_s + text])
  end

  def send_to_items(api, args)
    @nodes.each_value do |node|
      event(api, node.id, args) if node.kind == "SubscriptionItem" && node.props["shoes_api_name"] == api
    end
    nil
  end

  def resize(message)
    @nodes[message["app"]]&.props&.merge!("width" => message["w"], "height" => message["h"])
    write(t: "resize", app: message["app"], w: message["w"], h: message["h"])
  end

  def snapshot(path)
    File.binwrite(path, PNG)
    app = @nodes[@apps.first]
    { path: path, w: app&.props&.fetch("width", 1), h: app&.props&.fetch("height", 1) }
  end

  def wire_key(name)
    name.length == 1 ? name : ":#{name}"
  end

  def node_at(x, y)
    return nil if x.nil? || y.nil? || x.negative? || y.negative? || x >= 100

    boxed[(y / ROW).floor]
  end

  def center_of(node)
    [50, boxed.index(node) * ROW + ROW / 2]
  end

  def text_of(node)
    return node.props["text"] if node.props["text"].is_a?(String)
    return nil unless node.props["text_items"]

    node.props["text_items"].map { |item| item.is_a?(Integer) ? text_of(@nodes[item]) : item }.join
  end

  # Rules

  def take_rules(key, message)
    matching = @rules.select do |rule|
      rule["on"] == key && (rule["match"] || {}).all? { |field, value| message[field] == value }
    end
    @rules -= matching
    matching
  end

  def emit_rule(rule)
    return unless rule["emit"]

    if rule["after"]
      @scheduled << [now + rule["after"], rule["emit"]]
    else
      emit(rule["emit"])
    end
  end

  def emit_scheduled
    due, @scheduled = @scheduled.partition { |at, _| at <= now }
    due.each { |_, messages| emit(messages) }
  end

  def emit(messages)
    messages.each do |message|
      copies = message["app"] == "each" ? @apps.map { |app| message.merge("app" => app) } : [message]
      copies.each { |copy| write(resolve(copy)) }
    end
  end

  def next_timeout
    return nil if @scheduled.empty?

    [@scheduled.map(&:first).min - now, 0].max
  end

  def resolve(message)
    message = message.dup
    message["app"] = @apps.first if message["app"] == "first"
    %w[target id].each do |field|
      message[field] = find_node(message[field])&.id if message[field].is_a?(Hash)
    end
    message
  end

  def find_node(spec)
    @order.map { |id| @nodes[id] }.find do |node|
      (spec["kind"].nil? || node.kind == spec["kind"]) && (spec["text"].nil? || text_of(node) == spec["text"])
    end
  end

  def crash(rule)
    return unless rule

    $stderr.puts(rule["crash"])
    $stderr.flush
    exit!(101)
  end

  def event(name, target, args)
    write(t: "event", name: name, target: target, args: args)
  end

  def write(message)
    $stdout.write(JSON.generate(message) + "\n")
    nil
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end

FakeChild.new.run
