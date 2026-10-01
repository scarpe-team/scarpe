# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in scarpe.gemspec
gemspec

gem "lacci", path: "lacci"
gem "scarpe-components", path: "scarpe-components"

# webview_ruby 0.1.2 plus a Windows (WebView2) build; see vendor/webview_ruby/README.md.
# require: false, as a gemspec dependency would be: exe/scarpe --dev runs Bundler.require, and
# loading it builds its native library, which only the webview display needs.
gem "webview_ruby", path: "vendor/webview_ruby", require: false

gem "rake", "~> 13.0"

group :test do
  gem "minitest", "~> 5.0"
  gem "minitest-reporters"
end

group :development do
  gem "yard"
  gem "redcarpet"
  gem "debug"
  gem "rubocop", "~> 1.21"
  gem "htmlbeautifier"
  gem "diff-lcs"
  #gem "commonmarker"
  #gem "github-markup"
end
