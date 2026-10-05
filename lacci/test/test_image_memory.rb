# frozen_string_literal: true

require_relative "test_helper"

class TestImageMemory < NienteTest
  def test_memory_dimensions_are_absent_on_a_display_without_bitmap_support
    run_test_niente_code(<<~'APP', app_test_code: <<~'TEST')
      Shoes.app { @page = image "memory:page" }
    APP
      assert_nil imagesize("memory:page")
      assert_equal [nil, nil], image("@page").size
      assert_nil image("@page").full_width
      assert_nil image("@page").full_height
    TEST
  end
end
