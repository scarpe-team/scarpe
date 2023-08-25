# frozen_string_literal: true

require "scarpe/components/file_helpers"

module Scarpe::Components
  class SegmentedFileLoader
    include Scarpe::Components::FileHelpers

    # Add a new segment type (e.g. "catscradle") with a different
    # file handler.
    #
    # @param type [String] the new name for this segment type
    # @param handler [Object] an object that will be called as obj.call(filename) - often a proc
    # @return <void>
    def add_segment_type(type, handler)
      if segment_type_hash.key?(type)
        raise "Segment type #{type.inspect} already exists!"
      end

      segment_type_hash[type] = handler
    end

    # Return an Array of segment type labels, such as "code" and "app_test".
    #
    # @return Array<String> the segment type labels
    def segment_types
      segment_type_hash.keys
    end

    # Load a .sca file with an optional YAML frontmatter prefix and
    # multiple file sections which can be treated differently.
    #
    # The file loader acts like a proc, being called with .call()
    # and returning true or false for whether it has handled the
    # file load. This allows chaining loaders in order and the
    # first loader to recognise a file will run it.
    #
    # @param path [String] the file or directory to treat as a Scarpe app
    # @return [Boolean] return true if the file is loaded as a segmented Scarpe app file
    def call(path)
      return false unless path.end_with?(".scas")

      file_load(path)
      true
    end

    private

    def gen_name(segmap)
      ctr = (1..10_000).detect { |i| !segmap.key?("%5d" % i) }
      "%5d" % ctr
    end

    def tokenize_segments(contents)
      require "yaml" # Only load when needed
      require "English"

      segments = contents.split(/\n-{5,}/)
      front_matter = {}

      # The very first segment can start with front matter, or with a divider, or with no divider.
      if segments[0].start_with?("---\n") || segments[0] == "---"
        # We have YAML front matter at the start. All later segments will have a divider.
        front_matter = YAML.load segments[0]
        front_matter ||= {} # If the front matter is just the three dashes it returns nil
        segments = segments[1..-1]
      elsif segments[0].start_with?("-----")
        # We have a divider at the start. Great! We're already well set up for this case.
      elsif segments.size == 1
        # No front matter, no divider, a single unnamed segment. No more parsing needed.
        return [{}, { "" => segments[0] }]
      else
        # No front matter, no divider before the first segment, multiple segments.
        # We'll add an artificial divider to the first segment for uniformity.
        segments = ["-----\n" + segments[0]] + segments[1..-1]
      end

      segmap = {}
      segments.each do |segment|
        if segment =~ /\A-* +(.*?)\n/
          # named segment with separator
          segmap[::Regexp.last_match(1)] = ::Regexp.last_match.post_match
        elsif segment =~ /\A-* *\n/
          # unnamed segment with separator
          segmap[gen_name(segmap)] = ::Regexp.last_match.post_match
        else
          raise "Internal error when parsing segments in segmented app file! seg: #{segment.inspect}"
        end
      end

      [front_matter, segmap]
    end

    def file_load(path)
      contents = File.read(path)

      front_matter, segmap = tokenize_segments(contents)

      if segmap.empty?
        raise "Illegal segmented Scarpe file: must have at least one code segment, not just front matter!"
      end

      # Match up front_matter[:segments] with the segments, or use the default of shoes and app_test.

      if front_matter[:segments]
        if front_matter[:segments].size != segmap.size
          raise "Number of front matter :segments must equal number of file segments!"
        end

        sth = segment_type_hash
        sv = segmap.values
        front_matter[:segments].each.with_index do |seg_name, idx|
          unless sth.key?(seg_name)
            raise "Unrecognized segment type #{seg_name.inspect}! No matching segment type available!"
          end

          # Match the segment-type loader with the segment contents
          with_tempfile("scarpe_segment_contents", sv[idx]) do |segment_contents_path|
            sth[seg_name].call(segment_contents_path)
          end
        end
      elsif segmap.size == 1
        # If there's only one segment, load it as Shoes code
        eval segmap.values[0]
      elsif segmap.size == 2
        # If there are two segments, the first is Shoes code and the second is APP_TEST_CODE
        # TODO: write a better loader for app_test code that doesn't set an env var and generally
        #    break ordering.
        segs = segmap.values
        with_tempfile("scarpe_seg_test_code", segs[1]) do |tf|
          # This will get picked up when Scarpe.app() runs. It will execute in the Scarpe::App.
          # Note that unlike app_test_code in test_helper this does *not* load CatsCradle or
          # set it up for testing.
          ENV["SCARPE_APP_TEST"] = tf
          eval segs[0]
        end
      else
        raise "Segmented files with more than two segments have to specify what they're for!"
      end
    end

    # The hash of segment type labels mapped to handlers which will be called.
    # Normal client code shouldn't ever call this.
    #
    # @return Hash<String, Object> the name/handler pairs
    def segment_type_hash
      @segment_handlers ||= {
        "shoes" => proc { |seg_file| load seg_file },
        "app_test" => proc { |seg_file| ENV["SCARPE_APP_TEST"] = seg_file },
      }
    end
  end
end

# You can add additional segment types to the segmented file loader
# loader = Scarpe::Components::SegmentedFileLoader.new
# loader.add_segment_type "capybara", proc { |seg_file| load_file_as_capybara(seg_file) }
# Shoes.add_file_loader loader
