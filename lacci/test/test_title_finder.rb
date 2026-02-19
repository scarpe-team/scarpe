# frozen_string_literal: true

require_relative "test_helper"

class TestTitleFinder < NienteTest
  def test_title_finder_finds_title_para
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        title "Hello World"
        para "Regular paragraph"
      end
    SHOES_APP
t = title
assert_equal "Hello World", t.text
    SHOES_SPEC
  end

  def test_banner_finder_finds_banner_para
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        banner "Big Banner"
      end
    SHOES_APP
b = banner
assert_equal "Big Banner", b.text
    SHOES_SPEC
  end

  def test_caption_finder
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        caption "A caption"
      end
    SHOES_APP
c = caption
assert_equal "A caption", c.text
    SHOES_SPEC
  end

  def test_subtitle_finder
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        subtitle "A subtitle"
      end
    SHOES_APP
s = subtitle
assert_equal "A subtitle", s.text
    SHOES_SPEC
  end

  def test_tagline_finder
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        tagline "A tagline"
      end
    SHOES_APP
tl = tagline
assert_equal "A tagline", tl.text
    SHOES_SPEC
  end

  def test_inscription_finder
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        inscription "Small text"
      end
    SHOES_APP
i = inscription
assert_equal "Small text", i.text
    SHOES_SPEC
  end

  def test_titles_plural_finder
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        title "First Title"
        title "Second Title"
        para "Not a title"
      end
    SHOES_APP
all_titles = titles
assert_equal 2, all_titles.size
    SHOES_SPEC
  end

  def test_title_finder_raises_when_none
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC, expect_minitest_exception: true)
      Shoes.app do
        para "Just a para"
      end
    SHOES_APP
assert_raises(Shoes::Errors::NoDrawablesFoundError) do
  title
end
    SHOES_SPEC
  end

  def test_title_size_is_symbol
    # Verify that title() creates Para with :title symbol, not numeric size
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        title "My Title"
      end
    SHOES_APP
all_paras = Shoes::App.find_drawables_by(Shoes::Para)
title_para = all_paras.find { |p| p.text == "My Title" }
assert_equal :title, title_para.size
assert_kind_of Symbol, title_para.size
    SHOES_SPEC
  end
end
