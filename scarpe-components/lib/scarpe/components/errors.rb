# frozen_string_literal: true

# Also defined in scarpe_core
class Scarpe::Error < StandardError; end

module Scarpe
  class InternalError < Scarpe::Error; end

  class FileContentError < Scarpe::Error; end

  class NoOperationError < Scarpe::Error; end

  class DuplicateFileError < Scarpe::Error; end

  class NoSuchFile < Scarpe::Error; end

  class MustOverrideMethod < Scarpe::Error; end

  class InvalidHTMLTag < Scarpe::Error; end
end
