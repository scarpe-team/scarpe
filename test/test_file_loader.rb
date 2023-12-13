# frozen_string_literal: true

require "test_helper"

class TestScarpeFileLoader < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  def file_load_test(app_code, test_code, extension)
    test_method_name = self.name
    test_class_name = self.class.name

    sspec_file = File.expand_path(File.join __dir__, "sspec.json")
    File.unlink(sspec_file) if File.exist?(sspec_file)

    test_method_name = self.name
    test_class_name = self.class.name

    with_tempfiles([
      [["scarpe_log_config", ".json"], JSON.dump(log_config_for_test)],
      [["scarpe_app_#{test_method_name}", extension], app_code],
      [["scarpe_test_#{test_method_name}", ".rb"], test_code || ""],
    ]) do |log_config, app_filename, test_filename|
      if test_code
        test_env = "SHOES_SPEC_TEST=\"#{test_filename}\""
      else
        test_env = ""
      end

      cmd = <<~TEST_CMD.gsub("\n", " ").gsub(/\s+/, " ")
        SCARPE_DISPLAY_SERVICE=wv_local
        SCARPE_HTML_RENDERER=calzini
        SCARPE_LOG_CONFIG=\"#{log_config}\"
        #{test_env}
        SHOES_MINITEST_EXPORT_FILE=\"#{sspec_file}\"
        SHOES_MINITEST_CLASS_NAME=\"#{test_class_name}\"
        SHOES_MINITEST_METHOD_NAME=\"#{test_method_name}\"
        LOCALAPPDATA=\"#{Dir.tmpdir}\"
        ruby #{SCARPE_EXE} --debug --dev \"#{app_filename}\"
      TEST_CMD

      STDERR.puts "CMD: #{cmd.inspect}"
      return system(cmd)
    end
  end

  # Run a test with an app, adding Shoes-Spec code so it will exit immediately
  def file_load_app_test(contents, extension, timeout: 10.0, exit_immediately: true)
    test_code = <<~TEST_CODE
      timeout #{timeout}
      #{exit_immediately ? "exit_on_first_heartbeat" : ""}
    TEST_CODE

    file_load_test(contents, test_code, extension)
  end

  def file_load_spec_test(contents, extension)
    file_load_test(contents, nil, extension)
  end

  def test_file_loader_simple_rb_file
    assert_equal true, file_load_app_test(<<~CODE, ".rb")
      Shoes.app do
        button "OK"
      end
    CODE
  end

  def test_file_loader_simple_rb_file_runs
    with_tempfile("any_file_touch", "") do |tmp_location|
      File.unlink(tmp_location) if File.exist?(tmp_location)

      assert_equal true, file_load_app_test(<<~CODE, ".rb")
        File.write(#{tmp_location.inspect}, "foo")
      CODE

      assert_equal "foo", File.read(tmp_location)
    end
  end
end
