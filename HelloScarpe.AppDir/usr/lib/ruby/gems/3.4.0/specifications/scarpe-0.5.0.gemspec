# -*- encoding: utf-8 -*-
# stub: scarpe 0.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "scarpe".freeze
  s.version = "0.5.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/scarpe-team/scarpe/blob/main/CHANGELOG.md", "homepage_uri" => "https://github.com/scarpe-team/scarpe" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Marco Concetto Rudilosso".freeze, "Noah Gibbs".freeze, "Nicholas Schwaderer".freeze]
  s.bindir = "exe".freeze
  s.date = "1980-01-02"
  s.email = ["marcoc.r@outlook.com".freeze, "the.codefolio.guy@gmail.com".freeze, "nicholas.schwaderer@gmail.com".freeze]
  s.executables = ["scarpe".freeze]
  s.files = ["exe/scarpe".freeze]
  s.homepage = "https://github.com/scarpe-team/scarpe".freeze
  s.licenses = ["MIT".freeze]
  s.post_install_message = "\n              (\\(\\\n              (>':')\n            o(__\")\")\n\n           Welcome to Scarpe!\n        Let's hop into some magic!\n\n        \u{1F3A9}\u2728 Abracadabra! \u2728\u{1F430}\n\n        Scarpe is tying itself to your system...\n        Don't worry, it's as easy as putting on bunny slippers!\n\n        Are you ready to bounce into a world of wonder?\n\n    Enjoy your magical journey with Scarpe!\n".freeze
  s.required_ruby_version = Gem::Requirement.new(">= 3.2.0".freeze)
  s.rubygems_version = "3.6.9".freeze
  s.summary = "Scarpe - shoes but running on webview".freeze

  s.installed_by_version = "3.7.2".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<base64>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<fastimage>.freeze, ["~> 2.2.7".freeze])
  s.add_runtime_dependency(%q<nokogiri>.freeze, ["~> 1.15.2".freeze])
  s.add_runtime_dependency(%q<sqlite3>.freeze, ["~> 1.6.3".freeze])
  s.add_runtime_dependency(%q<webrick>.freeze, ["~> 1.7.0".freeze])
  s.add_runtime_dependency(%q<lacci>.freeze, ["~> 0.4.0".freeze])
  s.add_runtime_dependency(%q<scarpe-components>.freeze, ["~> 0.4.0".freeze])
  s.add_runtime_dependency(%q<logging>.freeze, ["~> 2.3.1".freeze])
  s.add_runtime_dependency(%q<webview_ruby>.freeze, ["~> 0.1.1".freeze])
end
