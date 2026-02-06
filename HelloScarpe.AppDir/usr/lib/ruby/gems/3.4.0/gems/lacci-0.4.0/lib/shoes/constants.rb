# frozen_string_literal: true

require_relative "changelog"
class Shoes
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
      ]

      top, file = homes.detect { |home_top, _| home_top && File.exist?(home_top) }
      return nil if top.nil?
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

    # These should be set up by the Display Service when it loads. They are intentionally
    # *not* frozen so that the Display Service can add to them (and then optionally
    # freeze them.)

    # Fonts currently loaded and available
    FONTS = []

    # Standard features available in this display service - see KNOWN_FEATURES.
    # These may or may not require the Shoes.app requesting them per-app.
    FEATURES = []

    # Nonstandard extensions, e.g. Scarpe extensions, supported by this display lib.
    # An application may have to request the extensions for them to be available so
    # that a casual reader can see Shoes.app(features: :scarpe) and realize why
    # there are nonstandard styles or drawables.
    EXTENSIONS = []

    # These are all known features supported by this version of Lacci.
    # Features on this list are allowed to be in FEATURES. Anything else
    # goes in EXTENSIONS and is nonstandard.
    KNOWN_FEATURES = [
      :html, # Supports .to_html on display objects, HTML classes on drawables, etc.
    ].freeze
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
