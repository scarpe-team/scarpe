# frozen_string_literal: true

# These can be used for unit tests, but also more generally.

require_relative "file_helpers"

module Scarpe::Components::ProcessHelpers
  include Scarpe::Components::FileHelpers

  # Run the command and capture its stdout and stderr output, and whether
  # it succeeded or failed. Return after the command has completed.
  # The awkward name is because this is normally a component of another
  # library. Ordinarily you'd want to raise a library-specific exception
  # on failure, print a library-specific message or delimiter, or otherwise
  # handle success and failure. This is too general as-is.
  #
  # @param cmd [String,Array<String>] the command to run in Kernel#spawn format
  # @return [Array(String,String,bool)] the stdout output, stderr output and success/failure of the command in a 3-element Array
  def run_out_err_result(cmd)
    out_str = ""
    err_str = ""
    success = nil

    with_tempfiles([
      ["scarpe_cmd_stdout", ""],
      ["scarpe_cmd_stderr", ""],
    ]) do |stdout_file, stderr_file|
      pid = Kernel.spawn(cmd, out: stdout_file, err: stderr_file)
      Process.wait(pid)
      success = $?.success?
      out_str = File.read stdout_file
      err_str = File.read stderr_file
    end

    [out_str, err_str, success]
  end
end
