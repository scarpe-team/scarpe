# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
end

Rake::TestTask.new(:lacci_test) do |t|
  t.libs << "lacci/test"
  t.libs << "lacci/lib"
  t.test_files = FileList["lacci/test/**/test_*.rb"]
end

Rake::TestTask.new(:component_test) do |t|
  t.libs << "scarpe-components/test"
  t.libs << "scarpe-components/lib"
  t.test_files = FileList["scarpe-components/test/**/test_*.rb"]
end

namespace :test do
  desc 'Regenerate HTML fixtures'
  task :regenerate_html_fixtures do
    load 'tasks/regenerate_html_fixtures.rb'
  end

  desc 'Check HTML fixtures against latest output'
  task :check_html_fixtures do
    load 'tasks/check_html_fixtures.rb'
  end
end

RuboCop::RakeTask.new

task default: [:test, :lacci_test, :component_test]
