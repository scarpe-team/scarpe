# frozen_string_literal: true

require_relative "test_helper"

class TestDownload < NienteTest
  # handle_response called handle_failure(code) against def handle_failure(code,
  # logger), so every non-2xx answer logged an ArgumentError instead (ledger X18).
  def test_a_failed_download_logs_the_status
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~'SHOES_SPEC')
      Shoes.app { para "downloads" }
    SHOES_APP
      require "net/http"
      require "stringio"
      Net::HTTP.prepend(Module.new do
        def connect; end

        def request(_req, _body = nil)
          Net::HTTPNotFound.new("1.1", "404", "Not Found").tap { |res| res.instance_variable_set(:@read, true) }
        end
      end)

      called = false
      log, $stdout = $stdout, StringIO.new
      begin
        Shoes.APPS.first.download("http://shoes.invalid/missing") { called = true }.join(5)
        printed = $stdout.string
      ensure
        $stdout = log
      end

      assert_includes printed, "Failed to download content. Response code: 404"
      refute_includes printed, "wrong number of arguments"
      refute called, "the block waits for a download that worked"
    SHOES_SPEC
  end
end
