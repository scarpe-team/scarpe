# frozen_string_literal: true

require_relative "lib/scarpe/version"

Gem::Specification.new do |spec|
  spec.name = "scarpe"
  spec.version = Scarpe::VERSION
  spec.authors = ["Marco Concetto Rudilosso"]
  spec.email = ["marcoc.r@outlook.com"]

  spec.summary = "Scarpe - shoes but running on webview"
  spec.homepage = "https://github.com/Maaarcocr/scarpe"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Maaarcocr/scarpe"
  spec.metadata["changelog_uri"] = "https://github.com/Maaarcocr/scarpe/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "fastimage"
  spec.add_dependency "glimmer-dsl-libui"
  spec.add_dependency "logging", "~>2.3.1"
  spec.add_dependency "webview_ruby", "~>0.1.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
