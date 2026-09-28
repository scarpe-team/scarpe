# frozen_string_literal: true

class Shoes
  # What Shoes.on_error and Shoes::Program#on_error hand over when a handler, a timer or a
  # program's startup raises: a Hash with String keys, plain data a child process can send
  # its parent as JSON.
  #
  #   "class"     the error's class name, "NoMethodError"
  #   "message"   its message, as Ruby wrote it
  #   "backtrace" an Array of Strings, innermost first
  #   "path"      the file the error is in, the program's own when it is there
  #   "line"      the line in that file (an Integer), or nil
  #   "during"    "startup", "handler", "timer" or "exit"
  module ErrorReport
    DURING = %w[startup handler timer exit].freeze

    # Scarpe's own code, which "path" skips so it names the program's line. Display services
    # add their directories.
    LIBRARY_DIRS = [File.expand_path("..", __dir__) + "/"]

    module_function

    # @param error [Exception]
    # @param during [String] one of DURING
    # @param program [String, nil] the program's main file, preferred for "path" and "line"
    # @return [Hash{String => Object}]
    def from(error, during:, program: nil)
      during = during.to_s
      raise ArgumentError, "during is one of #{DURING.join(", ")}, not #{during.inspect}" unless DURING.include?(during)

      path, line = where(error, program)
      {
        "class" => error.class.name.to_s,
        "message" => message_of(error),
        "backtrace" => Array(error.backtrace).map(&:to_s),
        "path" => path,
        "line" => line,
        "during" => during,
      }
    end

    # [path, line]: for a SyntaxError the place Ruby names in its message, otherwise the
    # innermost frame in the program's file, else the innermost that is not Scarpe's own code.
    def where(error, program = nil)
      if error.is_a?(SyntaxError)
        path = error.respond_to?(:path) && error.path ? error.path : nil
        line = message_of(error)[/\A#{Regexp.escape(path.to_s)}:(\d+):/, 1] if path
        line ||= message_of(error)[/:(\d+):/, 1]
        return [path || program, line&.to_i]
      end

      frames = frames_of(error)
      found = (program && frames.find { |path, _line| same_file?(path, program) }) ||
        frames.find { |path, _line| !library?(path) }
      found || [nil, nil]
    end

    # [[path, line], ...], innermost first, from the error's backtrace.
    def frames_of(error)
      locations = error.backtrace_locations
      return locations.map { |l| [l.absolute_path || l.path, l.lineno] } if locations

      Array(error.backtrace).filter_map do |frame|
        m = frame.match(/\A(.+?):(\d+)(?::in |\z)/)
        m && [m[1], m[2].to_i]
      end
    end

    def library?(path)
      path.nil? || path.start_with?("<internal:") || path.include?("/gems/") ||
        LIBRARY_DIRS.any? { |dir| File.expand_path(path).start_with?(dir) }
    end

    # Ruby names a loaded file by its real path, and on a Mac /var and /tmp are links into
    # /private, so two spellings of one file are compared by where they lead too.
    def same_file?(a, b)
      File.expand_path(a) == File.expand_path(b) || File.realpath(a) == File.realpath(b)
    rescue ArgumentError, SystemCallError
      false
    end

    # The message, as valid UTF-8 whatever the error put in it, so it travels as JSON.
    def message_of(error)
      message = error.message.to_s
      message = message.dup.force_encoding(Encoding::UTF_8) unless message.encoding == Encoding::UTF_8
      message.valid_encoding? ? message : message.scrub("?")
    rescue StandardError
      error.class.name.to_s
    end
  end
end
