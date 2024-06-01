# frozen_string_literal: true

require_relative "test_helper"

require "scarpe/components/segmented_file_loader"

SEG_TEST_DATA = {}

class TestSegmentedAppFiles < Minitest::Test
  include Scarpe::Test::Helpers

  def setup
    @orig_file_loaders = Shoes.file_loaders
    Shoes.reset_file_loaders # create new loaders array with no overlap with @orig_file_loaders
    SEG_TEST_DATA.clear

    @loader = Scarpe::Components::SegmentedFileLoader.new
    Shoes.add_file_loader @loader
  end

  def teardown
    Shoes.set_file_loaders(@orig_file_loaders)
  end

  def test_add_segment_type
    @loader.add_segment_type("new_seg_type", proc { true })
  end

  def test_default_single_segment_with_front_matter
    app = <<~SEG_TEST_FILE
      ---
      front_matter: yes
      ----- app code
      SEG_TEST_DATA[:app_ran] = true
    SEG_TEST_FILE
    with_tempfile(["segfile_test_app", ".scas"], app) do |app_file|
      Shoes.run_app(app_file)
    end

    assert_equal({ app_ran: true }, SEG_TEST_DATA)
  end

  def test_default_single_segment_no_front_matter_with_initial_name
    app = <<~SEG_TEST_FILE
      ----- app code
      SEG_TEST_DATA[:app_ran] = true
    SEG_TEST_FILE
    with_tempfile(["segfile_test_app", ".scas"], app) do |app_file|
      Shoes.run_app(app_file)
    end

    assert_equal({ app_ran: true }, SEG_TEST_DATA)
  end

  def test_default_single_segment_no_front_matter_no_initial_name
    app = <<~SEG_TEST_FILE
      SEG_TEST_DATA[:app_ran] = true
    SEG_TEST_FILE
    with_tempfile(["segfile_test_app", ".scas"], app) do |app_file|
      Shoes.run_app(app_file)
    end

    assert_equal({ app_ran: true }, SEG_TEST_DATA)
  end

  # TODO: this test is partially updated to ShoesSpec rather
  # than CatsCradle, but we could use a proper version.
  def test_default_double_segment_with_front_matter
    app = <<~SEG_TEST_FILE
      ---
      front_matter: yes
      ----- app code
      SEG_TEST_DATA[:app_ran] = true
      eval File.read(ENV['SHOES_SPEC_TEST']) # run test code
      ----- test code
      SEG_TEST_DATA[:test_ran] = true
    SEG_TEST_FILE
    with_tempfile(["segfile_test_app", ".scas"], app) do |app_file|
      Shoes.run_app(app_file)
    end

    assert_equal({ app_ran: true, test_ran: true }, SEG_TEST_DATA)
  end

  def test_empty_front_matter
    app = <<~SEG_TEST_FILE
      ---
      ----- app code
      SEG_TEST_DATA[:app_ran] = true
      eval File.read(ENV['SHOES_SPEC_TEST']) # run test code
      ----- test code
      SEG_TEST_DATA[:test_ran] = true
    SEG_TEST_FILE
    with_tempfile(["segfile_test_app", ".scas"], app) do |app_file|
      Shoes.run_app(app_file)
    end

    assert_equal({ app_ran: true, test_ran: true }, SEG_TEST_DATA)
  end

  def test_default_double_segment_no_front_matter_with_initial_name
    app = <<~SEG_TEST_FILE
      ----- app code
      SEG_TEST_DATA[:app_ran] = true
      eval File.read(ENV['SHOES_SPEC_TEST']) # run test code
      ----- test code
      SEG_TEST_DATA[:test_ran] = true
    SEG_TEST_FILE
    with_tempfile(["segfile_test_app", ".scas"], app) do |app_file|
      Shoes.run_app(app_file)
    end

    assert_equal({ app_ran: true, test_ran: true }, SEG_TEST_DATA)
  end

  def test_unnamed_double_segments
    app = <<~SEG_TEST_FILE
      -----
      SEG_TEST_DATA[:app_ran] = true
      eval File.read(ENV['SHOES_SPEC_TEST']) # run test code
      -----
      SEG_TEST_DATA[:test_ran] = true
    SEG_TEST_FILE
    with_tempfile(["segfile_test_app", ".scas"], app) do |app_file|
      Shoes.run_app(app_file)
    end

    assert_equal({ app_ran: true, test_ran: true }, SEG_TEST_DATA)
  end

  def test_default_double_segment_no_front_matter_no_initial_name
    app = <<~SEG_TEST_FILE
      SEG_TEST_DATA[:app_ran] = true
      eval File.read(ENV['SHOES_SPEC_TEST']) # run test code
      ----- test code
      SEG_TEST_DATA[:test_ran] = true
    SEG_TEST_FILE
    with_tempfile(["segfile_test_app", ".scas"], app) do |app_file|
      Shoes.run_app(app_file)
    end

    assert_equal({ app_ran: true, test_ran: true }, SEG_TEST_DATA)
  end

  def test_extra_dashes_in_dividers
    app = <<~SEG_TEST_FILE
      ---
        front_matter: yes
      ---------------- app code
      SEG_TEST_DATA[:app_ran] = true
      eval File.read(ENV['SHOES_SPEC_TEST']) # run test code
      ------- test code
      SEG_TEST_DATA[:test_ran] = true
    SEG_TEST_FILE
    with_tempfile(["segfile_test_app", ".scas"], app) do |app_file|
      Shoes.run_app(app_file)
    end

    assert_equal({ app_ran: true, test_ran: true }, SEG_TEST_DATA)
  end

  def test_custom_segment_types
    # "shoes" type already exists and evaluates the code, don't need to add it
    @loader.add_segment_type("capybara", proc { |path| load path })
    @loader.add_segment_type("extra_data", proc { |path| load path })

    app = <<~SEG_TEST_FILE
      ---
      :segments:
      - shoes
      - capybara
      - extra_data
      -----
      SEG_TEST_DATA[:shoes_ran] = true
      -----
      SEG_TEST_DATA[:capy_ran] = true
      -----
      SEG_TEST_DATA[:extra_data_ran] = true
    SEG_TEST_FILE
    with_tempfile(["segfile_test_app", ".scas"], app) do |app_file|
      Shoes.run_app(app_file)
    end

    assert_equal({ shoes_ran: true, capy_ran: true, extra_data_ran: true }, SEG_TEST_DATA)
  end
end
