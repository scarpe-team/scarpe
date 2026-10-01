
# Appended to a copy of an app by scripts/native_cold_start.rb and test/package: once the first
# frame is painted, print one line of JSON to stderr (the time, frames painted, bytecode hits,
# YJIT, the default external encoding), save a snapshot if SCARPE_PROBE_SNAPSHOT names a PNG,
# then quit.
Scarpe::Native.on_first_heartbeat do
  automation = Scarpe::Native::DisplayService.instance.automation
  frames = automation.frames(1)
  at = Process.clock_gettime(Process::CLOCK_REALTIME)
  automation.snapshot(ENV["SCARPE_PROBE_SNAPSHOT"], scale: 2) if ENV["SCARPE_PROBE_SNAPSHOT"]
  loader = defined?(Scarpe::Package::Bytecode) && Scarpe::Package::Bytecode.loader
  yjit = defined?(RubyVM::YJIT) ? RubyVM::YJIT.enabled? : "absent"
  $stderr.puts "scarpe-probe #{JSON.generate(at: at, frames: frames, bytecode_hits: loader && loader.hits, yjit: yjit, ruby: RUBY_VERSION, encoding: Encoding.default_external.to_s)}"
  Shoes.quit
end
