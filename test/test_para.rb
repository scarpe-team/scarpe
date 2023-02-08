# frozen_string_literal: true

require "test_helper"

class TestPara < Minitest::Test
  def test_renders_paragraph
    para = Scarpe::Para.new("Hello World")
    html_id = para.html_id

    assert_equal "<p id=\"#{html_id}\">Hello World</p>", para.to_html
  end

  def test_renders_paragraph_with_collection_of_arguments
    text_collection = [
      "Testing test test. ",
      "Breadsticks. ",
      "Breadsticks. ",
      "Breadsticks. ",
      "Very good."
    ]

    para = Scarpe::Para.new(text_collection)
    html_id = para.html_id

    assert_equal "<p id=\"#{html_id}\">Testing test test. Breadsticks. Breadsticks. Breadsticks. Very good.</p>", para.to_html
  end

  def test_renders_a_magenta_paragraph
    para = Scarpe::Para.new("Hello World", stroke: :magenta)
    html_id = para.html_id

    assert_equal "<p id=\"#{html_id}\" style=\"color:magenta\">Hello World</p>", para.to_html
  end

  def test_renders_a_blue_paragraph_with_class_attribute
    para = Scarpe::Para.new("Hello World", class: :sea, stroke: :blue)
    html_id = para.html_id

    assert_equal "<p class=\"sea\" id=\"#{html_id}\" style=\"color:blue\">Hello World</p>", para.to_html
  end

end
