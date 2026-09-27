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

  # Ledger K5: start, progress and finish fire in order, each handed the download;
  # headers: and body: shape the request; save: writes the file and leaves the
  # response body nil, with the headers still there (manual 906-975).
  def test_events_request_styles_and_save
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~'SHOES_SPEC')
      Shoes.app { para "downloads" }
    SHOES_APP
      require "net/http"
      require "tmpdir"
      $sent = []
      Net::HTTP.prepend(Module.new do
        def connect; end

        def request(req, _body = nil)
          $sent << [req.method, req["x-asked-by"], req.body]
          Net::HTTPOK.new("1.1", "200", "OK").tap do |res|
            res["X-Shoes"] = "Curious"
            res.instance_variable_set(:@body, "Hello")
            res.instance_variable_set(:@read, true)
          end
        end
      end)

      app = Shoes.APPS.first
      seen = []
      app.download("http://shoes.invalid/a", method: "POST", headers: { "X-Asked-By" => "Shoes" }, body: "q=1",
        start: proc { |dl| seen << [:start, dl.percent] },
        progress: proc { |dl| seen << [:progress, dl.percent] },
        finish: proc { |dl| seen << [:finish, dl.response.body] }).join(5)
      assert_equal [[:start, 0], [:progress, 100], [:finish, "Hello"]], seen
      assert_equal ["POST", "Shoes", "q=1"], $sent.last

      Dir.mktmpdir do |dir|
        saved = nil
        app.download("http://shoes.invalid/b", save: File.join(dir, "b.txt")) { |dl| saved = dl }.join(5)
        assert_equal "Hello", File.read(File.join(dir, "b.txt"))
        assert_nil saved.response.body, "the data went to the file"
        assert_equal "Curious", saved.response.headers["x-shoes"]
      end
    SHOES_SPEC
  end
end
