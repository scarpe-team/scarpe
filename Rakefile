# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

# Rakefile

# The steps of the webview job in .github/workflows/ci.yml, in its order, stopping at the first
# failure. The webview tests open real windows. Nothing here installs, checks out or uploads:
# run `bundle install` first.
desc "Run the webview CI job's tests locally (opens windows)"
task :ci_test do
  ENV["CI_RUN"] = "true"
  %w[lacci_test component_test test:check_html_fixtures test].each { |name| Rake::Task[name].invoke }
end

# The steps of .github/workflows/native.yml's macOS and Linux legs, in its order, stopping at the
# first failure. Headless: no window opens, and the spec suite's stubs for dialogs, sounds and
# the clipboard go first on PATH, as in CI. docs/native_ci.md explains each step.
desc "Run the native CI jobs' steps locally, headless"
task :ci_native do
  ENV["PATH"] = [File.expand_path("spec/support/fakebin", __dir__), ENV["PATH"]].join(File::PATH_SEPARATOR)
  Dir.chdir(File.expand_path("native", __dir__)) do
    sh "cargo clippy --all-targets --release --locked -- -D warnings"
    sh "cargo test --release --locked"
    sh "cargo build --release --locked"
  end
  %w[native_test lacci_test component_test spec:selftest spec:check].each { |name| Rake::Task[name].invoke }
  sh "spec/run --display niente"
  sh "spec/run --display native --no-build"
  sh "spec/run --examples --display native --no-build"
  if RUBY_PLATFORM.include?("darwin")
    require "tmpdir"
    Dir.mktmpdir("scarpe-ci-package") { |dir| ruby "exe/scarpe", "package", "--native", "examples/button.rb", "--output", dir }
  end
  Rake::Task["package_test"].invoke
end

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/test_*.rb']
end

Rake::TestTask.new(:lacci_test) do |t|
  t.libs << 'lacci/test'
  t.libs << 'lacci/lib'
  t.test_files = FileList['lacci/test/**/test_*.rb']
end

# The Rust display service's Ruby side. Files are named *_test.rb so the test/**/test_*.rb
# glob above (webview) never picks them up.
Rake::TestTask.new(:native_test) do |t|
  t.libs << 'test/native'
  t.libs << 'lib'
  t.test_files = FileList['test/native/**/*_test.rb']
end

# `scarpe package`, native path included (docs/native_packaging.md). The build test needs the
# cached Traveling Ruby and skips without it.
Rake::TestTask.new(:package_test) do |t|
  t.libs << 'test/package'
  t.libs << 'lib'
  t.test_files = FileList['test/package/**/*_test.rb']
end

Rake::TestTask.new(:component_test) do |t|
  t.libs << 'scarpe-components/test'
  t.libs << 'scarpe-components/lib'
  t.test_files = FileList['scarpe-components/test/**/test_*.rb']
end

# WINDOWLESS=1 runs the fixture tasks' examples against tasks/windowless_webview, a stand-in for
# the webview_ruby gem: Scarpe builds the same HTML and no window opens. CI checks with the real
# webview. The stand-in is proven to load before any example runs, since the real one shows windows.
def windowless_webview!
  return unless ENV["WINDOWLESS"]

  ENV["RUBYOPT"] = ["-I#{File.expand_path("tasks/windowless_webview", __dir__)}", ENV["RUBYOPT"]].compact.join(" ")
  loaded = `bundle exec ruby -e 'require "webview_ruby"; print WebviewRuby::WINDOWLESS'`
  abort "WINDOWLESS: the webview stand-in did not load, so stopping before a window opens" unless loaded == "true"
end

namespace :test do
  desc 'Regenerate HTML fixtures (WINDOWLESS=1 opens no window)'
  task :regenerate_html_fixtures do |_t|
    ENV['SELECTED_FILE'] = ARGV[-1] if ARGV[-1].include?('.rb')
    windowless_webview!
    load 'tasks/regenerate_html_fixtures.rb'
  end

  desc 'Check HTML fixtures against latest output (WINDOWLESS=1 opens no window)'
  task :check_html_fixtures do |_t|
    ENV['SELECTED_FILE'] = ARGV[-1] if ARGV[-1].include?('.rb')
    windowless_webview!
    load 'tasks/check_html_fixtures.rb'
  end
end

task default: %i[test lacci_test component_test]

# The consolidated Shoes spec suite (spec/run). Tasks: spec:run, spec:examples, spec:check.
load "spec/spec.rake"
