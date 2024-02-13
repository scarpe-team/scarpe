# frozen_string_literal: true

load "lacci/lib/shoes/margin_helper.rb"


class TestMarginHelper < Minitest::Test
include MarginHelper

    def test_one_Number_margin

        kwargs = {:margin => 20}

        assert_equal({:margin => 20},margin_parse(kwargs))

    end

    def test_Array_four_margin

        kwargs = {:margin => [20,20,30,40]}

        assert_equal({:margin => nil, :margin_left => 20, :margin_top => 20, :margin_right => 30, :margin_bottom => 40},margin_parse(kwargs))

    end

    def test_Array_one_margin

        kwargs = {:margin => [20]}

        assert_equal({:margin => 20},margin_parse(kwargs))

    end


    def test_String_four_margin

        kwargs = {:margin => "20 30 40 50"}

        assert_equal({:margin => nil, :margin_left => "20", :margin_top => "30", :margin_right => "40", :margin_bottom => "50"},margin_parse(kwargs))

    end

    def test_String_one_margin

        kwargs = {:margin => "20"}

        assert_equal({:margin => "20"},margin_parse(kwargs))

    end

    def test_Hash_four_margin

        kwargs = {:margin => {left:20,top:20,right:30,bottom:30}}

        assert_equal({:margin => nil, :margin_left => 20, :margin_top => 20, :margin_right => 30, :margin_bottom => 30},margin_parse(kwargs))

    end

    def test_Hash_three_margin

        kwargs = {:margin => {top:20,right:30,bottom:30}}

        assert_equal({:margin => nil, :margin_top => 20, :margin_right => 30, :margin_bottom => 30},margin_parse(kwargs))

    end

    def test_Hash_two_margin

        kwargs = {:margin => {left:20,top:20}}

        assert_equal({:margin => nil, :margin_left => 20, :margin_top => 20},margin_parse(kwargs))

    end

    def test_Hash_one_margin

        kwargs = {:margin => {bottom:30}}

        assert_equal({:margin => nil, :margin_bottom => 30},margin_parse(kwargs))

    end

end
