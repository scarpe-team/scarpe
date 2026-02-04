# -*- encoding: utf-8 -*-
# stub: lacci 0.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "lacci".freeze
  s.version = "0.4.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/scarpe-team/scarpe/blob/main/CHANGELOG.md", "homepage_uri" => "https://github.com/scarpe-team/scarpe" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Marco Concetto Rudilosso".freeze, "Noah Gibbs".freeze]
  s.bindir = "exe".freeze
  s.date = "2024-05-06"
  s.email = ["marcoc.r@outlook.com".freeze, "the.codefolio.guy@gmail.com".freeze]
  s.homepage = "https://github.com/scarpe-team/scarpe".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2.0".freeze)
  s.rubygems_version = "3.5.3".freeze
  s.summary = "Lacci - a portable Shoes DSL with switchable display backends, part of Scarpe".freeze

  s.installed_by_version = "3.7.2".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<scarpe-components>.freeze, ["~> 0.4.0".freeze])
end
