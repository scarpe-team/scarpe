# frozen_string_literal: true

# The spec suite runner behind spec/run. No gems: it must work under plain `ruby spec/run`
# as well as `bundle exec`.

require "json"
require "time"
require "yaml"
require "fileutils"
require "tmpdir"
require "rbconfig"
require "etc"
require "zlib"

module SpecSuite
  SPEC_DIR = File.expand_path("..", __dir__)
  REPO = File.expand_path("..", SPEC_DIR)
  RESULTS_DIR = File.join(SPEC_DIR, "results")
  SUPPORT_DIR = File.join(SPEC_DIR, "support")
  BUILTIN_STUB = File.join(SUPPORT_DIR, "builtin_stub.rb")
  FAKEBIN = File.join(SUPPORT_DIR, "fakebin")
  ASSETS_DIR = File.join(SUPPORT_DIR, "assets")
  MANUAL = File.join(REPO, "docs", "static", "manual.md")
  MANUAL_INVENTORY = File.join(REPO, "native", "research", "manual_inventory.json")
  EXAMPLES_YML = File.join(SPEC_DIR, "examples.yml")
  SCARPE_EXE = File.join(REPO, "exe", "scarpe")

  DISPLAYS = %w[niente native].freeze

  # Every status a case or example can end with. "Bad" ones make spec/run exit non-zero.
  STATUSES = %w[pass fail error skip expected_fail unexpected_pass not_applicable timeout].freeze
  BAD_STATUSES = %w[fail error unexpected_pass timeout].freeze

  # Error text without machine-specific prefixes: repo paths become repo-relative and gem
  # paths start at the gem ("sqlite3-1.6.9/lib/..."), so results read the same everywhere.
  def self.tidy(text, *roots)
    ([*roots, REPO].map { |root| root + "/" }).reduce(text.to_s) { |out, prefix| out.gsub(prefix, "") }
      .gsub(%r{/\S*/gems/(?=[^/\s]+/)}, "")
  end

  def self.relative(path)
    path = File.expand_path(path)
    path.start_with?(SPEC_DIR + "/") ? path.delete_prefix(SPEC_DIR + "/") : path.delete_prefix(REPO + "/")
  end
end

require_relative "suite/case_file"
require_relative "suite/child"
require_relative "suite/sandbox"
require_relative "suite/minitest_outcome"
require_relative "suite/case_run"
require_relative "suite/example_list"
require_relative "suite/example_run"
require_relative "suite/gallery"
require_relative "suite/png"
require_relative "suite/results_file"
require_relative "suite/scoreboard"
require_relative "suite/pool"
require_relative "suite/cli"
