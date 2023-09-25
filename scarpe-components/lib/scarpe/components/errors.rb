# frozen_string_literal: true

module Scarpe
  class InternalError < Scarpe::Error; end

  class FileContentError < Scarpe::Error; end

  class NoOperationError < Scarpe::Error; end

  class DuplicateFileError < Scarpe::Error; end

  class NoSuchFile < Scarpe::Error; end

  class MustOverrideMethod < Scarpe::Error; end

  class InvalidHTMLTag < Scarpe::Error; end
end
