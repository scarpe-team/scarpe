# frozen_string_literal: true

module Scarpe::Exceptions

  class UnknownShoesEventAPIError < Shoes::Error; end

  class UnknownShapeCommandError < Shoes::Error; end

  class UnknownEventTypeError < Shoes::Error; end

  class UnexpectedSpecifierError < Shoes::Error; end

  class UnexpectedFiberTransferError < Shoes::Error; end

  class MultipleWidgetsFoundError < Shoes::Error; end

  class NoWidgetsFoundError < Shoes::Error; end

  class InvalidPromiseError < Shoes::Error; end

  class MissingComponentsError < Shoes::Error; end

  class ControlInterfaceInitializationError < Shoes::Error; end

  class IllegalSubscribeEventError < Shoes::Error; end

  class IllegalDispatchEventError < Shoes::Error; end

  class MissingBlockError < Shoes::Error; end

  class DuplicateCallbackError < Shoes::Error; end

  class JavaScriptBindingError < Shoes::Error; end

  class JavaScriptInitializationError < Shoes::Error; end

  class PeriodicHandlerSetupError < Shoes::Error; end

  class PeriodicHandlerSetupError < Shoes::Error; end

  class WebWranglerNotRunningError < Shoes::Error; end

  class NonexistentEvalResultError < Shoes::Error; end

  class JSRedrawError < Shoes::Error; end

  class SingletonError < Shoes::Error; end

  class DocumentRootNotCreatedError < Shoes::Error; end

  class ConnectionError < Shoes::Error; end

  class DatagramSendError < Shoes::Error; end

  class ParentProcessCreateDatagramError < Shoes::Error; end

  class ScarpeWebviewClassNotFoundError < Shoes::Error; end

  class MissingScarpeClassError < Shoes::Error; end

  class MissingPropertyError < Shoes::Error; end

  class WidgetLinkableIDError < Shoes::Error; end

end
