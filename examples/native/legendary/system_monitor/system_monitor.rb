# System Monitor: how hard your Mac is working, updated every second.
#
# CPU, memory and disk as rings, two minutes of history as a chart, and the
# processes doing the most. The numbers come from the same commands you could
# type in Terminal (ps, vm_stat, sysctl and df), and every one of them only reads.
# Space pauses and carries on.

BACKDROP = "#0d1117"
CARD = "#151b23"
EDGE = "#232c38"
TEXT = "#e6edf3"
MUTED = "#8b96a5"
FAINT = "#4a5563"
TEAL = "#4fd1c5"
VIOLET = "#a78bfa"
AMBER = "#f6c177"
BLUE = "#7aa2f7"
HISTORY = 120 # samples, one a second

# The machine: reads its numbers and hands them back as plain Ruby. No Shoes here.
class Machine
  def cores = @cores ||= [read("sysctl", "-n", "hw.ncpu").to_i, 1].max
  def memory_size = @memory_size ||= read("sysctl", "-n", "hw.memsize").to_i
  def chip = @chip ||= read("sysctl", "-n", "machdep.cpu.brand_string").strip

  # Every process: its id, its share of one core, the memory it holds, its name.
  def processes
    read("ps", "-Aceo", "pid=,pcpu=,rss=,comm=").lines.filter_map do |line|
      pid, cpu, rss, name = line.strip.split(" ", 4)
      { pid: pid.to_i, cpu: cpu.to_f, memory: rss.to_i * 1024, name: name } if name
    end
  end

  # All the processes' shares added up, over the number of cores: 0 to 100.
  def cpu(processes) = (processes.sum { |p| p[:cpu] } / cores).clamp(0, 100)

  # Memory as Activity Monitor counts it: what apps hold, what the system has wired
  # down, and what is squeezed into the compressor. Cached files come back when needed.
  def memory
    stats = read("vm_stat")
    page = stats[/page size of (\d+)/, 1].to_i
    pages = ->(name) { stats[/^#{name}:\s+(\d+)/, 1].to_i * page }
    apps = pages.("Anonymous pages") - pages.("Pages purgeable")
    wired = pages.("Pages wired down")
    compressed = pages.("Pages occupied by compressor")
    { apps: apps, wired: wired, compressed: compressed, used: apps + wired + compressed, total: memory_size,
      cached: pages.("File-backed pages") + pages.("Pages purgeable") }
  end

  # The start-up disk. On a Mac the system sits on a sealed volume of its own, so what
  # is used is the whole size less what is still free.
  def disk
    fields = read("df", "-k", "/").lines.last.to_s.split
    total, free = fields[1].to_i * 1024, fields[3].to_i * 1024
    { total: total, free: free, used: total - free }
  end

  def load = read("sysctl", "-n", "vm.loadavg").scan(/\d+\.\d+/).first(3).map(&:to_f)

  def swap
    usage = read("sysctl", "-n", "vm.swapusage")
    megabytes = ->(name) { usage[/#{name} = ([\d.]+)M/, 1].to_f * 1024 * 1024 }
    { used: megabytes.("used"), total: megabytes.("total") }
  end

  def up_since = Time.at(read("sysctl", "-n", "kern.boottime")[/sec = (\d+)/, 1].to_i)

  private

  # Runs a command without a shell and returns what it printed, or "" if it is missing.
  def read(*command)
    IO.popen(command, err: File::NULL, &:read)
  rescue SystemCallError
    ""
  end
end

Shoes.app(title: "System Monitor", width: 960, height: 664, resizable: false) do
  @machine = Machine.new
  @cpu_history = []
  @memory_history = []
  @sort = :cpu
  @shown = { cpu: 0.0, memory: 0.0, disk: 0.0 } # what the rings show, gliding towards the truth
  @truth = { cpu: 0.0, memory: 0.0, disk: 0.0 }

  # ---- little helpers ------------------------------------------------------------------

  def gigabytes(bytes) = format("%.1f GB", bytes / 1024.0**3)

  def memory_text(bytes)
    bytes >= 1024**3 ? gigabytes(bytes) : "#{(bytes / 1024.0**2).round} MB"
  end

  def label(text, **style)
    para text.upcase, size: 10, weight: "semibold", kerning: 1.5, stroke: MUTED, margin: 0, **style
  end

  def card(left, top, width, height, &contents)
    stack left: left, top: top, width: width, height: height do
      background CARD, curve: 16
      border EDGE, curve: 16
      contents.call
    end
  end

  # A ring: a faint track, a coloured arc that fills clockwise from twelve o'clock,
  # and the number in the middle.
  def ring(cx, cy, color)
    nofill
    strokewidth 10
    cap :curve
    stroke EDGE
    oval cx, cy, 104, center: true
    stroke color
    arc_shape = arc cx - 52, cy - 52, 104, 104, -Math::PI / 2, -Math::PI / 2 + 0.01
    number = para "", size: 26, weight: "light", stroke: TEXT, align: "center", left: cx - 50, top: cy - 20, width: 100, margin: 0
    [arc_shape, number]
  end

  def show_ring((arc_shape, number), percent)
    arc_shape.hidden = percent < 0.3
    arc_shape.angle2 = -Math::PI / 2 + 2 * Math::PI * [percent / 100.0, 0.9995].min
    number.replace "#{percent.round}%"
  end

  # A line of recent values along the foot of a card, 0 to 100.
  def sparkline(slot, values, color, width, height)
    slot.clear do
      next if values.size < 2

      step = width / (HISTORY / 2 - 1.0)
      recent = values.last(HISTORY / 2)
      points = recent.each_with_index.map { |v, i| [width - (recent.size - 1 - i) * step, height - v / 100.0 * height] }
      nostroke
      fill gradient(rgb(*color_parts(color), 0.22), rgb(*color_parts(color), 0.0))
      shape do
        move_to points.first[0], height
        points.each { |x, y| line_to x, y }
        line_to points.last[0], height
      end
      nofill
      stroke color
      strokewidth 1.5
      shape do
        move_to(*points.first)
        points.drop(1).each { |x, y| line_to x, y }
      end
    end
  end

  def color_parts(hex) = hex.scan(/\h\h/).map(&:hex)

  # ---- the window ----------------------------------------------------------------------

  def header
    flow left: 24, top: 22, width: 640, height: 46 do
      stack width: 40, height: 40 do
        background "#1c2430", curve: 11
        nofill
        strokewidth 3
        cap :curve
        stroke EDGE
        oval 20, 20, 22, center: true
        stroke TEAL
        arc 9, 9, 22, 22, -Math::PI / 2, Math::PI * 0.75
      end
      stack width: 500, margin_left: 12 do
        para "System Monitor", size: 18, weight: "semibold", stroke: TEXT, margin: 0
        @about = para "", size: 12, stroke: MUTED, margin: [0, 3, 0, 0]
      end
    end
    @live = flow left: 796, top: 30, width: 140, height: 30, tooltip: "Space pauses and carries on" do
      background "#1c2430", curve: 15
      border EDGE, curve: 15
      nostroke
      @live_dot = oval 14, 11, 8, fill: TEAL
      @live_text = para "Live", size: 12, weight: "semibold", stroke: TEXT, margin: [30, 7, 0, 0]
      @pause_text = para "Pause", size: 11, stroke: MUTED, align: "right", margin: [0, 8, 14, 0]
    end
    @live.click { toggle_pause }
  end

  def cpu_card
    card 20, 84, 296, 196 do
      label "CPU", left: 20, top: 18
      @load_text = para "", size: 11, stroke: MUTED, align: "right", left: 120, top: 16, width: 156, margin: 0
      @cpu_ring = ring 76, 104, TEAL
      stack left: 146, top: 64, width: 136 do
        @cores_text = para "", size: 13, stroke: TEXT, margin: 0
        para "busiest right now", size: 11, stroke: MUTED, margin: [0, 12, 0, 2]
        @busiest = para "", size: 12, weight: "semibold", stroke: TEAL, wrap: "trim", margin: 0
      end
      @cpu_spark = stack(left: 20, top: 166, width: 256, height: 20) {}
    end
  end

  def memory_card
    card 332, 84, 296, 196 do
      label "Memory", left: 20, top: 18
      @swap_text = para "", size: 11, stroke: MUTED, align: "right", left: 120, top: 16, width: 156, margin: 0
      @memory_ring = ring 76, 104, VIOLET
      stack left: 146, top: 56, width: 140 do
        @memory_used = para "", size: 13, stroke: TEXT, margin: [0, 0, 0, 8]
        @memory_parts = [["Apps", VIOLET], ["Wired", BLUE], ["Compressed", "#e0a3ff"]].map do |name, color|
          amount = nil
          flow height: 18 do
            nostroke
            fill color
            oval 0, 6, 7
            para name, size: 11, stroke: MUTED, margin: [12, 2, 0, 0]
            amount = para "", size: 11, stroke: TEXT, align: "right", margin: [0, 2, 8, 0]
          end
          amount
        end
      end
      @memory_spark = stack(left: 20, top: 166, width: 256, height: 20) {}
    end
  end

  def disk_card
    card 644, 84, 296, 196 do
      label "Disk", left: 20, top: 18
      para "Macintosh HD", size: 11, stroke: MUTED, align: "right", left: 120, top: 16, width: 156, margin: 0
      @disk_ring = ring 76, 104, AMBER
      stack left: 146, top: 64, width: 136 do
        @disk_used = para "", size: 13, stroke: TEXT, margin: 0
        para "still free", size: 11, stroke: MUTED, margin: [0, 12, 0, 2]
        @disk_free = para "", size: 16, weight: "semibold", stroke: AMBER, margin: 0
      end
      stack left: 20, top: 172, width: 256, height: 8 do
        background EDGE, curve: 4
        @disk_bar = background AMBER, curve: 4, width: 0
      end
    end
  end

  # Two minutes of CPU (the filled area) and memory (the line), newest on the right.
  def history_card
    card 20, 296, 560, 344 do
      label "The last two minutes", left: 22, top: 20
      flow left: 370, top: 17, width: 170 do
        [["CPU", TEAL, 60], ["Memory", VIOLET, 80]].each do |name, color, width|
          stack width: width do # shapes are placed, not flowed, so each key gets a slot of its own
            nostroke
            fill color
            rect 0, 6, 14, 4, curve: 2
            para name, size: 11, stroke: MUTED, margin: [20, 1, 0, 0]
          end
        end
      end
      stack left: 22, top: 56, width: 516, height: 250 do
        [0, 25, 50, 75, 100].each do |at|
          y = 220 - at * 2.1
          nostroke
          fill rgb(255, 255, 255, at.zero? ? 0.1 : 0.04)
          rect 36, y.round, 480, 1
          para "#{at}%", size: 10, stroke: FAINT, align: "right", left: 0, top: y - 7, width: 30, margin: 0
        end
        para "2 min ago", size: 10, stroke: FAINT, left: 36, top: 230, margin: 0
        para "1 min", size: 10, stroke: FAINT, align: "center", left: 246, top: 230, width: 60, margin: 0
        para "now", size: 10, stroke: FAINT, align: "right", left: 456, top: 230, width: 60, margin: 0
        @chart = stack(left: 36, top: 0, width: 480, height: 221) {}
      end
    end
  end

  def draw_history
    @chart.clear do
      next if @cpu_history.size < 2

      step = 480 / (HISTORY - 1.0)
      to_points = lambda do |values|
        values.each_with_index.map { |v, i| [480 - (values.size - 1 - i) * step, 220 - v * 2.1] }
      end
      cpu = to_points.(@cpu_history)
      nostroke
      fill gradient(rgb(79, 209, 197, 0.35), rgb(79, 209, 197, 0.02))
      shape do
        move_to cpu.first[0], 220
        cpu.each { |x, y| line_to x, y }
        line_to cpu.last[0], 220
      end
      nofill
      cap :curve
      stroke TEAL
      strokewidth 2
      shape do
        move_to(*cpu.first)
        cpu.drop(1).each { |x, y| line_to x, y }
      end
      memory = to_points.(@memory_history)
      stroke VIOLET
      shape do
        move_to(*memory.first)
        memory.drop(1).each { |x, y| line_to x, y }
      end
      nostroke
      fill TEAL
      oval(*cpu.last, 7, center: true)
      fill VIOLET
      oval(*memory.last, 7, center: true)
    end
  end

  def processes_card
    card 596, 296, 344, 344 do
      label "Top processes", left: 22, top: 20
      @sorts = {}
      flow left: 196, top: 12, width: 128, height: 28 do
        background "#0f141b", curve: 14
        { cpu: "CPU", memory: "Memory" }.each do |key, name|
          look = words = nil
          segment = stack width: 64, height: 28 do
            look = background EDGE, curve: 11, margin: 3, hidden: true
            words = para name, size: 11, weight: "semibold", stroke: MUTED, align: "center", margin: [0, 7, 0, 0]
          end
          segment.click { sort_processes_by(key) }
          @sorts[key] = [look, words]
        end
      end
      @count_text = para "", size: 11, stroke: FAINT, left: 22, top: 316, margin: 0
      @rows = (0...8).map do |i|
        row = {}
        stack left: 22, top: 54 + i * 32, width: 300, height: 32 do
          row[:name] = para "", size: 12.5, stroke: TEXT, wrap: "trim", left: 0, top: 8, width: 150, margin: 0
          nostroke
          fill EDGE
          rect 160, 13, 60, 6, curve: 3
          fill TEAL
          row[:bar] = rect 160, 13, 0, 6, curve: 3
          row[:value] = para "", size: 12, weight: "semibold", stroke: TEXT, align: "right", left: 222, top: 8, width: 76, margin: 0
        end
        row
      end
    end
  end

  # ---- every second --------------------------------------------------------------------

  def sample
    processes = @machine.processes
    memory = @machine.memory
    disk = @machine.disk
    @processes = processes
    @truth[:cpu] = @machine.cpu(processes)
    @truth[:memory] = memory[:total].positive? ? memory[:used] * 100.0 / memory[:total] : 0
    @truth[:disk] = disk[:total].positive? ? disk[:used] * 100.0 / disk[:total] : 0
    @cpu_history = (@cpu_history + [@truth[:cpu]]).last(HISTORY)
    @memory_history = (@memory_history + [@truth[:memory]]).last(HISTORY)

    load = @machine.load
    @load_text.replace(load.empty? ? "" : "load #{load.map { |l| format("%.2f", l) }.join("  ")}")
    @cores_text.replace "#{@machine.cores} cores"
    busiest = processes.max_by { |p| p[:cpu] }
    @busiest.replace(busiest ? "#{busiest[:name]}, #{busiest[:cpu].round}%" : "")
    swap = @machine.swap
    @swap_text.replace(swap[:total].positive? ? "swap #{gigabytes(swap[:used])} of #{gigabytes(swap[:total])}" : "no swap in use")
    @memory_used.replace "#{gigabytes(memory[:used])} of #{gigabytes(memory[:total])}"
    @memory_parts.zip(memory.values_at(:apps, :wired, :compressed)).each { |amount, bytes| amount.replace gigabytes(bytes) }
    @disk_used.replace "#{gigabytes(disk[:used])} of #{gigabytes(disk[:total])}".gsub(/\.\d GB/, " GB")
    @disk_free.replace gigabytes(disk[:free])
    @disk_bar.width = (256 * @truth[:disk] / 100).round

    sparkline(@cpu_spark, @cpu_history, TEAL, 256, 20)
    sparkline(@memory_spark, @memory_history, VIOLET, 256, 20)
    draw_history
    show_processes
    @since_sample = 0
    @glide.start
  end

  def show_processes
    return unless @processes

    top = @processes.sort_by { |p| -p[@sort] }.first(@rows.size)
    biggest = @sort == :cpu ? [top.first&.dig(:cpu).to_f, 100].max : top.first&.dig(:memory).to_f
    @rows.each_with_index do |row, i|
      process = top[i]
      row[:name].replace process ? process[:name] : ""
      value = process ? process[@sort] : 0
      row[:value].replace(process ? (@sort == :cpu ? "#{value.round(1)}%" : memory_text(value)) : "")
      row[:bar].style(width: biggest.positive? ? (60 * value / biggest).round : 0, fill: @sort == :cpu ? TEAL : VIOLET)
    end
    @count_text.replace "#{@processes.size} processes, sorted by #{@sort == :cpu ? "CPU" : "memory"}"
  end

  def sort_processes_by(key)
    @sort = key
    @sorts.each do |each_key, (look, words)|
      look.hidden = each_key != key
      words.stroke = each_key == key ? TEXT : MUTED
    end
    show_processes
  end

  def toggle_pause
    @paused = !@paused
    @paused ? @ticker.stop : @ticker.start
    @live_text.replace(@paused ? "Paused" : "Live")
    @pause_text.replace(@paused ? "Carry on" : "Pause")
    @live_dot.fill = @paused ? FAINT : TEAL
    sample unless @paused
  end

  # ---- putting it together -------------------------------------------------------------

  background BACKDROP
  header
  cpu_card
  memory_card
  disk_card
  history_card
  processes_card
  sort_processes_by :cpu

  up = ((Time.now - @machine.up_since) / 86_400).floor
  memory_size = (@machine.memory_size / 1024.0**3).round
  about = [@machine.chip, "#{@machine.cores} cores", "#{memory_size} GB of memory"]
  about << (up >= 1 ? "up #{up} #{up == 1 ? "day" : "days"}" : "up since #{@machine.up_since.strftime("%H:%M")}")
  @about.replace about.reject(&:empty?).join("  ·  ")

  # The rings glide towards each new reading, and the live dot dims between them.
  # Once everything has arrived the animation stops, so a still screen costs nothing.
  @glide = animate(30) do
    @since_sample += 1
    @shown.each_key do |key|
      @shown[key] += (@truth[key] - @shown[key]) * 0.25
      @shown[key] = @truth[key] if (@truth[key] - @shown[key]).abs < 0.05
    end
    settled = @shown == @truth
    show_ring(@cpu_ring, @shown[:cpu])
    show_ring(@memory_ring, @shown[:memory])
    show_ring(@disk_ring, @shown[:disk])
    @live_dot.fill = rgb(*color_parts(TEAL), [1 - @since_sample / 20.0, 0.35].max) unless @paused
    @glide.stop if settled && @since_sample >= 14
  end

  sample
  @ticker = every(1) { sample }
  keypress { |key| toggle_pause if key == " " }
end
