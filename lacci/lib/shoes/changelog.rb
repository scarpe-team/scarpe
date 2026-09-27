# frozen_string_literal: true

require_relative "log"
# require "scarpe/components/modular_logger"

class Shoes
  class Changelog
    # include Shoes::Log

    def initialize
      #TODO : refer to  https://github.com/scarpe-team/scarpe/pull/400
      #       and figure out how to use scarpe logger here without getting duplicate or nil error
      # Shoes::Log.instance = Scarpe::Components::ModularLogImpl.new
      # log_init("Changelog")
    end

    # root_dir duplicates constants.rb, but how to share?
    def get_latest_release_info(root_dir = File.dirname(__FILE__, 4))
      revision = git_revision(root_dir)

      changelog_file = "#{root_dir}/CHANGELOG.md"
      if File.exist?(changelog_file)
        # UTF-8 whatever the locale: a packaged app starts with no LANG, where Ruby reads US-ASCII.
        changelog_content = File.read(changelog_file, encoding: Encoding::UTF_8)
        release_name_pattern = /^## \[(\d+\.\d+\.\d+)\] - (\d{4}-\d{2}-\d{2}) - (\w+)$/m
        release_matches = changelog_content.scan(release_name_pattern)
        latest_release = release_matches.max_by { |version, _date, _name| Gem::Version.new(version) }

        if latest_release
          #puts "Found release #{latest_release[0]} in CHANGELOG.md"
          # @log.debug("Found release #{latest_release[0]} in CHANGELOG.md") # Logger isn't initialized yet
          version_parts = latest_release[0].split(".").map(&:to_i)
          rel_id = ("%02d%02d%02d" % version_parts).to_i

          return({
            RELEASE_NAME: latest_release[2],
            RELEASE_BUILD_DATE: latest_release[1],
            RELEASE_ID: rel_id,
            REVISION: revision,
          })
        end
      end

      puts "No release found in CHANGELOG.md"
      { RELEASE_NAME: nil, RELEASE_BUILD_DATE: nil, RELEASE_ID: nil, REVISION: revision }
    end

    private

    # The checkout's commit, asked of the checkout itself rather than of wherever the
    # app runs from (ledger L3), or nil outside a git checkout (a packaged app).
    def git_revision(root_dir)
      return nil unless File.exist?("#{root_dir}/.git")

      revision = IO.popen(["git", "-C", root_dir, "rev-parse", "HEAD"], err: File::NULL, &:read).chomp
      revision.empty? ? nil : revision
    rescue SystemCallError
      nil
    end
  end
end
