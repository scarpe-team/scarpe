# -*- encoding: utf-8 -*-
Gem::Specification.new do |s|
  s.name = "webview_ruby"
  s.version = "0.1.2"
  s.authors = ["Marek"]
  s.summary = "Ruby bindings for webview"
  s.files = ["lib/webview_ruby.rb", "lib/webview_ruby/version.rb"]
  s.require_paths = ["lib"]
  s.add_dependency "ffi"
  s.add_dependency "ffi-compiler"
  s.add_dependency "rake"
end
