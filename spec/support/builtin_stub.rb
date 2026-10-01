# frozen_string_literal: true

# spec/run loads this into every child process with RUBYOPT=-r<this file>, before Bundler,
# Lacci or any display service. It has two jobs:
#
# 1. No case or example may ever open a real OS dialog. Lacci answers an unanswered builtin
#    (ask, confirm, ask_open_file...) with an osascript dialog (lacci/lib/shoes/builtins.rb).
#    We record every dialog builtin, answer stubbed ones, give unanswered ones the headless
#    defaults from DESIGN 5.2, and make osascript unreachable.
# 2. Give test code the display-agnostic helpers the suite documents: stub_dialog and
#    dialog_calls everywhere, and the missing Shoes-Spec triggers on Niente's proxy.
#
# Nothing here may require a gem, not even a default gem like json: it runs before Bundler,
# and activating json 3.0 here breaks a Gemfile that locks json 2.x. JSON is only required
# lazily, on the first dialog, long after Bundler has set up.

module SpecSuite
  module Dialogs
    KINDS = %w[alert confirm ask ask_color ask_open_file ask_save_file ask_open_folder ask_save_folder].freeze

    HEADLESS_ANSWERS = {
      "alert" => nil, "confirm" => false, "ask" => "", "ask_color" => nil,
      "ask_open_file" => nil, "ask_save_file" => nil, "ask_open_folder" => nil, "ask_save_folder" => nil,
    }.freeze

    class << self
      def calls
        @calls ||= []
      end

      def stub(kind, value)
        kind = kind.to_s
        raise ArgumentError, "Unknown dialog kind #{kind.inspect}; use one of #{KINDS.join(", ")}" unless KINDS.include?(kind)

        queued[kind] << value
      end

      def stubbed?(kind)
        !queued[kind].empty?
      end

      def take(kind)
        queued[kind].shift
      end

      def headless_answer(kind)
        HEADLESS_ANSWERS[kind]
      end

      private

      def queued
        @queued ||= Hash.new { |hash, kind| hash[kind] = [] }.tap { |queues| load_from_env(queues) }
      end

      # Front matter `dialogs:` arrives as JSON, e.g. {"ask":["Nick"],"confirm":true}, so dialogs
      # called at the top of a file, before any test code runs, can be answered too.
      def load_from_env(queues)
        stubs = ENV["SPEC_DIALOG_STUBS"]
        return if stubs.nil? || stubs.empty?

        require "json"
        JSON.parse(stubs).each do |kind, values|
          answers = values.is_a?(Array) ? values : [values] # a bare nil is one Cancel, not none
          answers.each { |value| queues[kind.to_s] << value }
        end
      end
    end
  end

  # Prepended to Shoes::Builtins.
  module AnsweredBuiltins
    private

    def shoes_builtin(cmd_name, *args)
      return super unless Dialogs::KINDS.include?(cmd_name)

      Dialogs.calls << [cmd_name.to_sym, *args]
      return Dialogs.take(cmd_name) if Dialogs.stubbed?(cmd_name)

      super
    end

    # Dialogs get their headless answers; anything else (the clipboard, whose stand-in file
    # SCARPE_CLIPBOARD_FILE names) is Lacci's to answer.
    def native_builtin_fallback(cmd_name, *args)
      return super unless Dialogs::KINDS.include?(cmd_name)

      Dialogs.headless_answer(cmd_name)
    end

    def osascript(_script)
      warn "[spec] refused to open a real OS dialog through osascript"
      nil
    end
  end

  # Included into Minitest::Test, so every display's test class has them unless it defines its own.
  module TestHelpers
    # Answer the next `kind` dialog with `value`. A cancelled ask returns "" (ledger K1); a
    # cancelled file, folder or colour dialog returns nil.
    def stub_dialog(kind, value)
      Dialogs.stub(kind, value)
    end

    # Every dialog builtin the app called, in order, as [kind, *args]: [[:alert, "Good job."]].
    def dialog_calls
      Dialogs.calls.map(&:dup)
    end
  end

  # Included into Niente::ShoesSpecProxy. Niente fires Lacci events directly (no hit-testing);
  # these match the argument shapes a real display sends (DESIGN 4.3).
  module NienteTriggers
    def trigger_change(value)
      ::Shoes::DisplayService.dispatch_event("change", linkable_id, value)
    end

    def trigger_release(button = 1, x = 0, y = 0)
      ::Shoes::DisplayService.dispatch_event("release", linkable_id, button, x, y)
    end

    def trigger_motion(x, y)
      ::Shoes::DisplayService.dispatch_event("motion", linkable_id, x, y)
    end
  end

  # Prepended to Niente::ShoesSpecProxy, whose own respond_to_missing? calls the drawable's
  # private respond_to_missing? and raises NoMethodError (lacci/lib/scarpe/niente/shoes_spec.rb).
  module NienteRespondTo
    def respond_to_missing?(name, include_private = false)
      @obj.respond_to?(name, include_private)
    end
  end

  INSTALLERS = {
    "Shoes::Builtins" => ->(builtins) { builtins.prepend(AnsweredBuiltins) },
    "Minitest::Test" => ->(test_class) { test_class.include(TestHelpers) },
    "Niente::ShoesSpecProxy" => lambda do |proxy_class|
      NienteTriggers.instance_methods.each do |name|
        next if proxy_class.method_defined?(name)

        proxy_class.define_method(name, NienteTriggers.instance_method(name))
      end
      proxy_class.prepend(NienteRespondTo)
    end,
  }

  MODULE_NAME = Module.instance_method(:name)

  # The targets are defined long after this file runs, so install each one as its body closes.
  INSTALL_TRACE = TracePoint.new(:end) do |tp|
    installer = INSTALLERS.delete(MODULE_NAME.bind_call(tp.self))
    installer&.call(tp.self)
    INSTALL_TRACE.disable if INSTALLERS.empty?
  end
end

SpecSuite::INSTALL_TRACE.enable
