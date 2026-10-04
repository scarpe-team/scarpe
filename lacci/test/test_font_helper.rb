# frozen_string_literal: true

require_relative "test_helper"


class TestFontHelper < Minitest::Test
include FontHelper
    def test_parse_full_font

        string = "Pacifico 20px bold italic small-caps"

        assert_equal(["italic", "small-caps" , "bold" , "20px" , "Pacifico"],parse_font(string))

    end

    def test_parse_quotesFamily
        string = "'Times new roman', serif 20px bold italic small-caps"
    
        assert_equal(["italic", "small-caps", "bold", "20px", "'Times new roman', serif"],parse_font(string))
    end

    def test_parse_empty
        string = ""

        assert_equal([nil,nil,nil,nil,""],parse_font(string))
    end

    def test_parse_onlyFamily
        string = "arial"

        assert_equal([nil,nil,nil,nil,"arial"],parse_font(string))
    end

    def test_parse_onlySize
        string = "40px"

        assert_equal([nil,nil,nil,"40px",""],parse_font(string))
    end

    def test_parse_onlyFontStyle
        string = "italic"

        assert_equal(["italic",nil,nil,nil,""],parse_font(string))
    end

    def test_parse_onlyFontVariant
        string = "small-caps"

        assert_equal([nil,"small-caps",nil,nil,""],parse_font(string))
    end

    def test_parse_onlyFontWeight
        string = "900"

        assert_equal([nil,nil,"900",nil,""],parse_font(string))
    end

    def test_parse_named_weights_without_changing_the_family
        weights = {
            "Thin" => "100", "Hairline" => "100",
            "UltraLight" => "200", "ExtraLight" => "200", "Light" => "300",
            "Regular" => "400", "Book" => "400", "Medium" => "500",
            "SemiBold" => "600", "DemiBold" => "600", "Strong" => "700",
            "UltraBold" => "800", "ExtraBold" => "800", "Heavy" => "900", "Black" => "900",
        }
        weights.each do |name, weight|
            [name, name.downcase, name.upcase].each do |spelling|
                assert_equal [nil, nil, weight, nil, "Example Serif"], parse_font("Example Serif #{spelling}"), spelling
            end
        end
    end

    def test_parse_existing_keywords_case_insensitively
        assert_equal ["italic", "small-caps", "bold", "x-large", "Inter"],
            parse_font("Inter BoLd ItAlIc SmAlL-CaPs X-LaRgE")
        assert_equal ["oblique", nil, "bolder", "20px", "Inter"],
            parse_font("Inter BOLDER OBLIQUE 20px")
        assert_equal [nil, nil, "lighter", nil, "Inter"], parse_font("Inter LIGHTER")
        assert_equal [nil, nil, nil, nil, "Inter"], parse_font("Inter NORMAL")
    end

    def test_parse_quoted_families_keeps_weight_names_and_numbers
        ["'Example Medium 2'", '"Example Medium 2"', "'Bold'", '"Bold"'].each do |family|
            assert_equal [nil, nil, "600", "18px", "#{family}, serif"],
                parse_font("#{family}, serif SemiBold 18px")
        end
    end

    def test_parse_leading_black_as_a_family_name
        assert_equal [nil, nil, "bold", nil, "Black Chancery"], parse_font("Black Chancery Bold")
    end

    def test_parse_numeric_weights_and_sizes
        %w[100 200 300 400 500 600 700 800 900].each do |weight|
            assert_equal [nil, nil, weight, "18", "Example Serif"], parse_font("Example Serif #{weight} 18")
        end
    end
end
