# frozen_string_literal: true

require_relative "cats_cradle"
require "scarpe/components/segmented_file_loader"

require "tmpdir"

module Scarpe
  class CatsCradleFileLoader
    def call(filename)
      ext = File.extname(filename)
      cc_instance = Scarpe::CCInstance.instance

      case ext
      when ".rb"
        cc_instance.active_fiber do
          load filename
        end
        cc_instance.fiber_start
      when ".scas", ".sspec"
        contents = File.read filename
        fm, segs = Scarpe::Components::SegmentedFileLoader.front_matter_and_segments_from_file(contents)

        app_key, spec_key, _ = *segs.keys
        app_filename = filename.gsub(".scas", ".rb").gsub(".sspec", ".rb")
        spec_filename = app_filename.gsub(".rb", ".test_code")

        d = Dir.mktmpdir("scarpe_#{File.basename filename}")
        File.write("#{d}/#{app_filename}", segs[app_key])
        File.write("#{d}/#{spec_filename}", segs[spec_key]) if spec_key

        cc_instance.active_fiber do
          # APPDATA is where a Shoes app stores temp data if needed
          ENV["APPDATA"] = d
          if spec_key
            ENV["SHOES_SPEC_TEST"] = "#{d}/#{spec_filename}"

            if ENV["SHOES_MINITEST_EXPORT_FILE"]
              sspec_export = ENV["SHOES_MINITEST_EXPORT_FILE"]
            else
              sspec_export = File.expand_path "sspec.json"
              ENV["SHOES_MINITEST_EXPORT_FILE"] = sspec_export
            end
            File.unlink(sspec_export) if File.exist?(sspec_export)
          else
            ENV.delete("SHOES_SPEC_TEST")
          end
          load "#{d}/#{app_filename}"
        end
        cc_instance.fiber_start
      else
        raise Shoes::BadFilenameError, "Unexpected file extension for file: #{filename.inspect}!"
      end

      true
    end
  end
end
