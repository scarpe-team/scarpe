# frozen_string_literal: true

require "test_helper"

class TestEditBox < Minitest::Test
  def setup
    @app = Minitest::Mock.new
    @app.expect :append, nil, [String]
    @app.expect :bind, nil, [Object]
    @app.expect :bind, nil, [Object]
  end

  def test_renders_textarea
    edit_box = Scarpe::EditBox.new(app, "Hello, World!")
    object_id = edit_box.object_id

    assert_equal(
      "<textarea id=\"#{object_id}\" oninput=\"scarpeHandler(#{object_id}, this.value)\">Hello, World!</textarea>",
      edit_box.render
    )
  end

  def test_renders_textarea_content_block
    edit_box = Scarpe::EditBox.new(app) { "Hello, World!" }
    object_id = edit_box.object_id

    assert_equal(
      "<textarea id=\"#{object_id}\" oninput=\"scarpeHandler(#{object_id}, this.value)\">Hello, World!</textarea>",
      edit_box.render
    )
  end

  def test_textarea_width
    edit_box = Scarpe::EditBox.new(app, "Hello, World!", width: 100)
    object_id = edit_box.object_id

    assert_equal(
      "<textarea id=\"#{object_id}\" oninput=\"scarpeHandler(#{object_id}, this.value)\" style=\"width:100px\">Hello, World!</textarea>",
      edit_box.render
    )
  end

  def test_textarea_height
    edit_box = Scarpe::EditBox.new(app, "Hello, World!", height: 100)
    object_id = edit_box.object_id

    assert_equal(
      "<textarea id=\"#{object_id}\" oninput=\"scarpeHandler(#{object_id}, this.value)\" style=\"height:100px\">Hello, World!</textarea>",
      edit_box.render
    )
  end

  def test_textarea_change_callback
    puts "TODO: test_textarea_change_callback"
  end

  private

  attr_reader :app
end
