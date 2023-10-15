# frozen_string_literal: true

require "tempfile"

# These can be used for unit tests, but also more generally.

module Scarpe; module Components; end; end
module Scarpe::Components::FileHelpers
  # Create a temporary file with the given prefix and contents.
  # Execute the block of code with it in place. Make sure
  # it gets cleaned up afterward.
  #
  # @param prefix [String] the prefix passed to Tempfile to identify this file on disk
  # @param contents [String] the file contents that should be written to Tempfile
  # @param dir [String] the directory to create the tempfile in
  # @yield The code to execute with the tempfile present
  # @yieldparam the path of the new tempfile
  def with_tempfile(prefix, contents, dir: Dir.tmpdir)
    t = Tempfile.new(prefix, dir)
    t.write(contents)
    t.flush # Make sure the contents are written out

    yield(t.path)
  ensure
    t.close
    t.unlink
  end

  # Create multiple tempfiles, with given contents, in given
  # directories, and execute the block in that context.
  # When the block is finished, make sure all tempfiles are
  # deleted.
  #
  # Pass an array of arrays, where each array is of the form:
  # [prefix, contents, (optional)dir]
  #
  # I don't love inlining with_tempfile's contents into here.
  # But calling it iteratively or recursively was difficult
  # when I tried it the obvious ways.
  #
  # This method should be equivalent to calling with_tempfile
  # once for each entry in the array, in a set of nested
  # blocks.
  #
  # @param tf_specs [Array<Array>] The array of tempfile prefixes, contents and directories
  # @yield The code to execute with those tempfiles present
  # @yieldparam An array of paths to tempfiles, in the same order as tf_specs
  def with_tempfiles(tf_specs, &block)
    tempfiles = []
    tf_specs.each do |prefix, contents, dir|
      dir ||= Dir.tmpdir
      t = Tempfile.new(prefix, dir)
      tempfiles << t
      t.write(contents)
      t.flush # Make sure the contents are written out
    end

    args = tempfiles.map(&:path)
    yield(args)
  ensure
    tempfiles.each do |t|
      t.close
      t.unlink
    end
  end
end
