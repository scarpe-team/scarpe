# frozen_string_literal: true

require_relative "lib/webview_ruby/version"

# webview_ruby 0.1.2 as published on rubygems.org, plus a Windows build.
# The macOS and Linux builds are unchanged. See README.md for what differs.
Gem::Specification.new do |spec|
  spec.name = "webview_ruby"
  spec.version = WebviewRuby::VERSION
  spec.authors = ["Marco Concetto Rudilosso"]
  spec.email = ["marcoc.r@outlook.com"]

  spec.summary = "Ruby bindings for webview"
  spec.homepage = "https://github.com/Maaarcocr/webview_ruby"
  spec.license = "MIT"

  spec.files = Dir["lib/**/*.rb", "ext/Rakefile", "ext/webview/*", "ext/webview-win/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/Rakefile"]

  spec.add_dependency "ffi"
  spec.add_dependency "rake"
  spec.add_dependency "ffi-compiler"
end
