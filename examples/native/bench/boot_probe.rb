# frozen_string_literal: true

# bench.rb loads this with RUBYOPT=-r to note the moment Ruby starts running code, the end of
# the VM's own boot in the cold-start timeline. Plain text, so it requires nothing.
if (dir = ENV["SCARPE_NATIVE_STATS"])
  File.write(File.join(dir, "boot.txt"), Process.clock_gettime(Process::CLOCK_REALTIME).to_s)
end
