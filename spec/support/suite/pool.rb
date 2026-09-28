# frozen_string_literal: true

module SpecSuite
  # Runs jobs on N threads; each job spawns and waits on its own child process.
  module Pool
    def self.map(items, jobs:)
      queue = Queue.new
      items.each_with_index { |item, index| queue << [item, index] }
      queue.close
      results = Array.new(items.size)
      lock = Mutex.new

      Array.new([jobs, items.size].min) do
        Thread.new do
          while (entry = queue.pop)
            item, index = entry
            result = yield item
            lock.synchronize do
              results[index] = result
              $stdout.print Scoreboard.progress(result)
              $stdout.flush
            end
          end
        end
      end.each(&:join)

      results
    end
  end
end
