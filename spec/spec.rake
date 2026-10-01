# frozen_string_literal: true

# Loaded from the Rakefile: `bundle exec rake spec:run`, `rake spec:run[native]`.
namespace :spec do
  run = File.expand_path("run", __dir__)

  desc "Run the .sspec suite (SPEC_DISPLAY=niente|native, JOBS=N, PATHS='manual/button ...')"
  task :run, [:display] do |_task, args|
    display = args[:display] || ENV.fetch("SPEC_DISPLAY", "niente")
    argv = ["--display", display]
    argv += ["--jobs", ENV["JOBS"]] if ENV["JOBS"]
    argv += ENV["PATHS"].split if ENV["PATHS"]
    ruby run, *argv
  end

  desc "Smoke-run every example in spec/examples.yml (SPEC_DISPLAY=niente|native)"
  task :examples, [:display] do |_task, args|
    display = args[:display] || ENV.fetch("SPEC_DISPLAY", "niente")
    ruby run, "--examples", "--display", display
  end

  desc "Validate every case's front matter without running anything"
  task :check do
    ruby run, "--check"
  end

  desc "Unit-test the spec runner itself (spec/support/test)"
  task :selftest do
    ruby File.expand_path("support/test/run.rb", __dir__)
  end
end
