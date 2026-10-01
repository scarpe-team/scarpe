# frozen_string_literal: true

module Scarpe::Native
  # Answers Lacci's "builtin" event synchronously (DESIGN 5.2). Every builtin gets an answer:
  # a stubbed one, a quiet default when nobody can click (headless runs and Shoes-Spec), or the
  # user's answer from a real dialog, which blocks until Rust replies.
  class Builtins
    DIALOGS = %w[alert confirm ask ask_color ask_open_file ask_save_file ask_open_folder ask_save_folder].freeze

    QUIET_ANSWERS = {
      "alert" => nil,
      "confirm" => false,
      "ask" => "",
      "ask_color" => nil,
      "ask_open_file" => nil,
      "ask_save_file" => nil,
      "ask_open_folder" => nil,
      "ask_save_folder" => nil,
    }.freeze

    # Every dialog asked for, as [kind, message], so tests can check an alert was shown.
    attr_reader :seen

    attr_writer :interactive

    def initialize(service, interactive:)
      @service = service
      @interactive = interactive
      @next_answers = Hash.new { |hash, kind| hash[kind] = [] }
      @standing_answers = {}
      @seen = []
      @log = Shoes::Log.logger("Scarpe::Native::Builtins")
    end

    # Answers the next `kind` dialog with value.
    def stub(kind, value)
      @next_answers[kind.to_s] << value
    end

    # Answers every `kind` dialog with value (the webview stub_ask(returns:) style).
    def stub_always(kind, value)
      @standing_answers[kind.to_s] = value
    end

    def answer(cmd_name, args)
      return dialog(cmd_name, args[0], args[1]) if DIALOGS.include?(cmd_name)

      case cmd_name
      when "font"
        @service.register_font(args.first)
      when "clipboard"
        return @service.clipboard
      when "clipboard="
        @service.clipboard = args.first
      else
        @log.warn("Unknown builtin #{cmd_name.inspect}(#{args.inspect[1..-2]}); answering nil")
      end
      nil
    end

    private

    def dialog(kind, message, options)
      @seen << [kind, message]
      return @next_answers[kind].shift unless @next_answers[kind].empty?
      return @standing_answers[kind] if @standing_answers.key?(kind)
      return QUIET_ANSWERS[kind] unless @interactive

      reply = @service.child.request(:dialog, kind: kind, message: message&.to_s, default: nil, **ask_options(options))
      if reply["error"]
        @log.warn("The #{kind} dialog failed: #{reply["error"]}")
        return QUIET_ANSWERS[kind]
      end
      # A cancelled ask answers "" (ledger K1, Q6): legacy scripts compare it without a nil check.
      return "" if kind == "ask" && reply["value"].nil?

      reply["value"]
    end

    # ask's options, which Lacci hands over beside the message (ledger K1): Rust masks a secret
    # answer as it is typed and heads the dialog with the title.
    def ask_options(options)
      return {} unless options.is_a?(Hash)

      options = options.transform_keys(&:to_s)
      { secret: (true if options["secret"]), title: options["title"]&.to_s }.compact
    end
  end
end
