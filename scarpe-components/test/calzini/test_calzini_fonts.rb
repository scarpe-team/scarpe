# frozen_string_literal: true

require_relative "../test_helper"

class TestCalziniFonts < Minitest::Test
  def setup
    @calzini = CalziniRenderer.new
  end

  def test_multiword_families_keep_spaces_and_capitalization
    assert_font "Fira Mono 18px", "normal normal normal 18px Fira Mono"
    assert_font "Times New Roman 20", "normal normal normal 20px Times New Roman"
    assert_font "Arial Unicode MS 18px", "normal normal normal 18px Arial Unicode MS"
    assert_font "Iowan Old Style, Georgia, serif 15px", "normal normal normal 15px Iowan Old Style, Georgia, serif"
  end

  def test_style_keywords_are_case_insensitive
    assert_font "Inter BoLd ItAlIc SmAlL-CaPs X-LaRgE", "italic small-caps bold x-large Inter"
    assert_font "Inter BOLDER OBLIQUE 20px", "oblique normal bolder 20px Inter"
    assert_font "Inter LIGHTER NORMAL", "normal normal lighter medium Inter"
  end

  def test_named_weights
    weights = {
      "Thin" => "100", "Hairline" => "100",
      "UltraLight" => "200", "ExtraLight" => "200", "Light" => "300",
      "Regular" => "400", "Book" => "400", "Medium" => "500",
      "SemiBold" => "600", "DemiBold" => "600", "Strong" => "700",
      "UltraBold" => "800", "ExtraBold" => "800", "Heavy" => "900", "Black" => "900",
    }
    weights.each do |name, weight|
      [name, name.downcase, name.upcase].each do |spelling|
        assert_font "Example Serif #{spelling} 18px", "normal normal #{weight} 18px Example Serif"
      end
    end
  end

  def test_quoted_families_keep_weight_names_and_numbers
    ["'Example Medium 2'", "'Bold'", "'Normal'"].each do |family|
      assert_font "#{family}, serif SemiBold 18px", "normal normal 600 18px #{family}, serif"
    end
  end

  def test_leading_black_is_part_of_the_family
    assert_font "Black Chancery Bold", "normal normal bold medium Black Chancery"
  end

  def test_numeric_weights_and_sizes
    %w[100 200 300 400 500 600 700 800 900].each do |weight|
      assert_font "Inter #{weight} 18", "normal normal #{weight} 18px Inter"
    end
    assert_font "Inter bold 1.5em", "normal normal bold 1.5em Inter"
  end

  def test_existing_lowercase_shorthand
    assert_font "italic normal bold 25px 'Times New Roman', serif", "italic normal bold 25px 'Times New Roman', serif"
  end

  def test_defaults_for_empty_or_partial_fonts
    assert_font "", "normal normal normal medium Arial"
    assert_font "Arial", "normal normal normal medium Arial"
    assert_font "18", "normal normal normal 18px Arial"
    assert_font "bold", "normal normal bold medium Arial"
  end

  private

  def assert_font(font, expected)
    %w[edit_line edit_box list_box].each do |control|
      html = @calzini.render(control, { "font" => font })
      assert_equal expected, html[/\bfont:([^;"]*)/, 1], "#{control} with #{font.inspect}"
    end
  end
end
