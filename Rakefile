# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

# Rakefile

task :ci_test do
  puts "
  \033[1;32;4;47mInstalling Dependencies\033[0m
  "

  system('brew install pkg-config portaudio')

 
  puts "
  \033[1;32;4;47mCheckout Code\033[0m
  "
  system('git checkout main')

 
  puts "
  \033[1;32;4;47mSetup Ruby and install Gems\033[0m
  "
  system('bundle install')

  # Run tests
  
  puts "
  \033[1;32;4;47mRun Lacci Tests\033[0m
  "
  system('CI_RUN=true bundle exec rake lacci_test')

  puts "
  \033[1;32;4;47mRun Scarpe-Component Tests\033[0m
  "

  system('CI_RUN=true bundle exec rake component_test')

 
  puts "
  \033[1;32;4;47mRun Scarpe Tests\033[0m
  "
  system('CI_RUN=true bundle exec rake test')

  
  puts "
  \033[1;32;4;47mCheck HTML Output\033[0m
  "
  system('bundle exec rake test:check_html_fixtures')

 
  puts "
  \033[1;32;4;47mUpload Fail logs\033[0m
  "
  system('if [ ! -z "$(ls logger/test_failure*.out.log 2>/dev/null)" ]; then actions/upload-artifact@v4 --name "test failure logs" --path logger/test_failure*.out.log; fi')
end

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
  task :regenerate_html_fixtures do |t|
    ENV['SELECTED_FILE'] = ARGV[-1] if ARGV[-1].include?(".rb")
    load 'tasks/regenerate_html_fixtures.rb'
  end

  desc 'Check HTML fixtures against latest output'
  task :check_html_fixtures do |t|
    ENV['SELECTED_FILE'] = ARGV[-1] if ARGV[-1].include?(".rb")
    load 'tasks/check_html_fixtures.rb'
  end
end

RuboCop::RakeTask.new

task default: [:test, :lacci_test, :component_test]
