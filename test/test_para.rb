# frozen_string_literal: true

require "test_helper"

class TestPara < Minitest::Test
  def test_renders_paragraph
    para = Scarpe::Para.new("Hello World")
    html_id = para.html_id

    assert_html para.to_html, :p, id: html_id, style: "font-size:12px" do
      "Hello World"
    end
  end

  def test_renders_paragraph_with_collection_of_arguments
    para = Scarpe::Para.new(
      "Testing test test. ",
      "Breadsticks. ",
      "Breadsticks. ",
      "Breadsticks. ",
      "Very good.",
    )

    assert_html para.to_html, :p, id: para.html_id, style: "font-size:12px" do
      "Testing test test. Breadsticks. Breadsticks. Breadsticks. Very good."
    end
  end

  def test_renders_a_magenta_paragraph
    para = Scarpe::Para.new("Hello World", stroke: :magenta)

    assert_html para.to_html, :p, id: para.html_id, style: "color:magenta;font-size:12px" do
      "Hello World"
    end
  end

  def test_renders_a_blue_paragraph_with_class_attribute
    para = Scarpe::Para.new("Hello World", class: :sea, stroke: :blue)

    assert_html para.to_html, :p, class: "sea", id: para.html_id, style: "color:blue;font-size:12px" do
      "Hello World"
    end
  end

  def test_renders_paragraph_with_size_number
    para = Scarpe::Para.new("Oh, to fling and be flung", size: 48)

    assert_html para.to_html, :p, id: para.html_id, style: "font-size:48px" do
      "Oh, to fling and be flung"
    end
  end

  def test_renders_paragraph_with_size_symbol
    para = Scarpe::Para.new("Oh, to fling and be flung", size: :banner)

    assert_html para.to_html, :p, id: para.html_id, style: "font-size:48px" do
      "Oh, to fling and be flung"
    end
  end
end
