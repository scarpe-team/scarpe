# frozen_string_literal: true

require_relative "test_helper"

# `image "cat.png", alt: "..."` names a picture for a screen reader (EXT, ledger N1). The native
# display reads it as the image's name; Shoes 3 had no such style.
class TestImageAlt < NienteTest
  def test_alt_is_a_style_sent_with_the_image
    run_test_niente_code(<<~SHOES_APP, app_test_code: <<~SHOES_SPEC)
      Shoes.app do
        @cat = image "cat.png", alt: "A sleeping cat"
        @plain = image "dog.png"
      end
    SHOES_APP
      assert_equal "A sleeping cat", image("@cat").alt
      assert_equal "A sleeping cat", image("@cat").style[:alt], "it travels with the image's styles"
      assert_nil image("@plain").alt
    SHOES_SPEC
  end
end
