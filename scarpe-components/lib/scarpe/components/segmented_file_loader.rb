# frozen_string_literal: true

module Scarpe::Components
  def self.segmented_file_load(path)
    require "yaml" # Only load when needed
    require "tempfile"
    require "English"

    contents = File.read(path)
    _front_matter = {}

    segments = contents.split("\n-----")

    if segments[0].start_with?("---/n") || segments[0] == "---"
      # We have YAML front matter at the start.
      # Eventually this will specify what different code segments do.
      _front_matter = YAML.load segments[0]
      if segments.size == 1
        raise "Illegal segmented Scarpe file: must have at least one code segment, not just front matter!"
      end

      segments = segments[1..-1]
    elsif segments.size == 1
      # Simplest segmented file there is: no front matter, no segments
      # @todo: indicate to Scarpe in some way that this is a Scarpe-specific
      #     file and extensions should be turned on?
      return load path
    end

    # Beyond this point, our segmented file has at least one code segment with a five-plus-dashes divider
    segmap = {}
    segments.each do |segment|
      if segment =~ /\A-*\s+(.*?)\n/
        # named segment
        segment = ::Regexp.last_match.post_match
        segmap[::Regexp.last_match(1)] = segment
      elsif segment[0] == "-"
        # unnamed segment
        segment =~ /\A-*/ || raise("Internal error! This regexp should always match!")
        segment = ::Regexp.last_match.post_match
        ctr = (1..10_000).detect { |i| !segmap.key?("%5d" % i) }
        gen_name = "%5d" % ctr

        segmap[gen_name] = segment
      else
        raise "Internal error when parsing segments in segmented app file!"
      end
    end

    if segmap.size == 1
      # If there's only one segment, load it as Shoes code
      eval segmap.values[0]
    elsif segmap.size == 2
      # If there are two segments, the first is Shoes code and the second is APP_TEST_CODE
      segs = segmap.values
      with_tempfile("scarpe_seg_test_code", segs[1]) do |tf|
        # This will get picked up when Scarpe.app() runs. It will execute in the Scarpe::App.
        # Note that unlike app_test_code in test_helper this does *not* load CatsCradle or
        # set it up for testing.
        ENV["SCARPE_APP_TEST"] = tf
        eval segs[0]
      end
    else
      # Later there will be more interesting customisable options for what to do with
      # different segments. For now, bail.
      raise "More complex segmentation files are not yet implemented!"
    end
  end

  # Can we share this with unit test helpers?
  def self.with_tempfile(prefix, contents, dir: Dir.tmpdir)
    t = Tempfile.new(prefix, dir)
    t.write(contents)
    t.flush # Make sure the contents are written out

    yield(t.path)
  ensure
    t.close
    t.unlink
  end

  # Load a .sca file with an optional YAML frontmatter prefix and
  # multiple file sections which can be treated differently.
  SEGMENTED_FILE_LOADER = lambda do |path|
    if path.end_with?(".scas")
      Scarpe::Components.segmented_file_load(path)
      return true
    end
    false
  end
end

# Shoes.add_file_loader Scarpe::Components::SEGMENTED_FILE_LOADER
