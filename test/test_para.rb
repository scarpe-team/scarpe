# frozen_string_literal: true

require "test_helper"

class TestPara < Minitest::Test
  def setup
    @app = Minitest::Mock.new
    @app.expect :append, nil, [String]
  end

  def test_renders_paragraph
    para = Scarpe::Para.new(app, "Hello World")
    object_id = para.object_id

    assert_equal "<p id=#{object_id}>Hello World</p>", para.render
  end

  def test_renders_paragraph_with_collection_of_arguments
    text_collection = [
      "Testing test test. ",
      "Breadsticks. ",
      "Breadsticks. ",
      "Breadsticks. ",
      "Very good."
    ]

    para = Scarpe::Para.new(app, text_collection)
    object_id = para.object_id

    assert_equal "<p id=#{object_id}>Testing test test. Breadsticks. Breadsticks. Breadsticks. Very good.</p>", para.render
  end

  private

  attr_reader :app
end
