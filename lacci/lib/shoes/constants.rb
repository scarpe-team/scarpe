# frozen_string_literal: true

require_relative "changelog"
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

    # A temp dir for Shoes app files
    LIB_DIR = find_lib_dir

    # the Shoes library dir
    DIR = File.dirname(__FILE__, 4)

    # Math constants from Shoes3
    RAD2PI = 0.01745329251994329577
    TWO_PI = 6.28318530717958647693
    HALF_PI = 1.57079632679489661923
    PI = 3.14159265358979323846
  end

  # Access and assign the release constants
  changelog_instance = Shoes::Changelog.new
  RELEASE_INFO = changelog_instance.get_latest_release_info
  RELEASE_NAME = RELEASE_INFO[:RELEASE_NAME]
  RELEASE_ID = RELEASE_INFO[:RELEASE_ID]
  RELEASE_BUILD_DATE = RELEASE_INFO[:RELEASE_BUILD_DATE]
  RELEASE_TYPE = "LOOSE_SHOES" # This isn't really a thing any more
  REVISION = RELEASE_INFO[:REVISION]
end
