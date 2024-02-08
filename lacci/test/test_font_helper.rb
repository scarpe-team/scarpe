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
end
