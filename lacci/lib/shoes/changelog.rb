# frozen_string_literal: true

require_relative "log"
# require "scarpe/components/modular_logger"

module Shoes
  class Changelog
    # include Shoes::Log

    def initialize
      #TODO : refer to  https://github.com/scarpe-team/scarpe/pull/400
      #       and figure out how to use scarpe logger here wtihout getting duplicate or nil error
      # Shoes::Log.instance = Scarpe::Components::ModularLogImpl.new
      # log_init("Changelog")
    end

    def get_latest_release_info
      changelog_content = File.read("CHANGELOG.md")

      release_name_pattern = /^## \[(\d+\.\d+\.\d+)\] - (\d{4}-\d{2}-\d{2})$/m

      release_matches = changelog_content.scan(release_name_pattern)

      latest_release = release_matches.max_by { |version, _date| Gem::Version.new(version) }

      if latest_release
        puts "Found release #{latest_release[0]} in CHANGELOG.md"
        # @log.debug("Found release #{latest_release[0]} in CHANGELOG.md")
        { RELEASE_NAME: latest_release[0], RELEASE_BUILD_DATE: latest_release[1] }
      else
        puts "No release found in CHANGELOG.md"
        { RELEASE_NAME: nil, RELEASE_BUILD_DATE: nil }
      end
    end
  end
end
