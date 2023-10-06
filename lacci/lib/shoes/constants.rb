# frozen_string_literal: true

module Shoes
  module Constants
    def self.find_lib_dir
      begin
        require "tmpdir"
      rescue LoadError
        return nil
      end
      homes = [
        [ENV["LOCALAPPDATA"], "Shoes"],
        [ENV["APPDATA"], "Shoes"],
        [ENV["HOME"], ".shoes"],
        [Dir.tmpdir, "shoes"],
      ]

      top, file = homes.detect { |home_top, _| home_top && File.exist?(home_top) }
      File.join(top, file)
    end

    LIB_DIR = find_lib_dir

    # Math constants from Shoes3
    RAD2PI = 0.01745329251994329577
    TWO_PI = 6.28318530717958647693
    HALF_PI = 1.57079632679489661923
    PI = 3.14159265358979323846
  end

  changelog_content = File.read("CHANGELOG.md")

  release_name_pattern = /^## \[(\d+\.\d+\.\d+)\] - (\d{4}-\d{2}-\d{2})$/m

  release_matches = changelog_content.scan(release_name_pattern)

  latest_release = release_matches.max_by { |version, _date| Gem::Version.new(version) }

  if latest_release
    RELEASE_NAME, RELEASE_BUILD_DATE = latest_release
  else
    puts "most likely something wrong in constants.rb file. or changelog"
  end
end
