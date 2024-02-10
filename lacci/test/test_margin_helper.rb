# frozen_string_literal: true

load "lacci/lib/shoes/margin_helper.rb"


class TestMarginHelper < Minitest::Test
include MarginHelper

    def test_one_Number_margin

        kwargs = {:margin => 20}

        assert_equal({:margin => nil, :margin_left => 20, :margin_top => 20, :margin_right => 20, :margin_bottom => 20},margin_parse(kwargs))

    end

    def test_Array_four_margin

        kwargs = {:margin => [20,20,30,40]}

        assert_equal({:margin => nil, :margin_left => 20, :margin_top => 20, :margin_right => 30, :margin_bottom => 40},margin_parse(kwargs))

    end

    def test_Array_three_margin

        kwargs = {:margin => [20,20,30]}

        assert_equal({:margin => nil, :margin_left => 20, :margin_top => 30, :margin_right => 20, :margin_bottom => 20},margin_parse(kwargs))

    end

    def test_Array_two_margin

        kwargs = {:margin => [20,30]}

        assert_equal({:margin => nil, :margin_left => 20, :margin_top => 20, :margin_right => 30, :margin_bottom => 30},margin_parse(kwargs))

    end

    def test_String_four_margin

        kwargs = {:margin => "20 30 40 50"}

        assert_equal({:margin => nil, :margin_left => "20", :margin_top => "30", :margin_right => "40", :margin_bottom => "50"},margin_parse(kwargs))

    end

    def test_String_three_margin

        kwargs = {:margin => "20 30 40"}

        assert_equal({:margin => nil, :margin_left => "20", :margin_top => "40", :margin_right => "30", :margin_bottom => "30"},margin_parse(kwargs))

    end

    def test_String_two_margin

        kwargs = {:margin => "20 30"}

        assert_equal({:margin => nil, :margin_left => "20", :margin_top => "20", :margin_right => "30", :margin_bottom => "30"},margin_parse(kwargs))

    end

end
