# frozen_string_literal: true

require "test_helper"

class TestEditBox < Minitest::Test
  def setup
    app = Minitest::Mock.new
    Scarpe::Widget.set_document_root(app)
    app.expect :bind, nil, [Object]
  end

  def test_renders_textarea
    edit_box = Scarpe::EditBox.new("Hello, World!")
    html_id = edit_box.html_id

    assert_equal(
      "<textarea id=\"#{html_id}\" oninput=\"scarpeHandler('#{html_id}-change', this.value)\">Hello, World!</textarea>",
      edit_box.to_html
    )
  end

  def test_renders_textarea_content_block
    edit_box = Scarpe::EditBox.new { "Hello, World!" }
    html_id = edit_box.html_id

    assert_equal(
      "<textarea id=\"#{html_id}\" oninput=\"scarpeHandler('#{html_id}-change', this.value)\">Hello, World!</textarea>",
      edit_box.to_html
    )
  end

  def test_textarea_width
    edit_box = Scarpe::EditBox.new("Hello, World!", width: 100)
    html_id = edit_box.html_id

    assert_equal(
      "<textarea id=\"#{html_id}\" oninput=\"scarpeHandler('#{html_id}-change', this.value)\" style=\"width:100px\">Hello, World!</textarea>",
      edit_box.to_html
    )
  end

  def test_textarea_height
    edit_box = Scarpe::EditBox.new("Hello, World!", height: 100)
    html_id = edit_box.html_id

    assert_equal(
      "<textarea id=\"#{html_id}\" oninput=\"scarpeHandler('#{html_id}-change', this.value)\" style=\"height:100px\">Hello, World!</textarea>",
      edit_box.to_html
    )
  end

  def test_textarea_change_callback
    puts "TODO: test_textarea_change_callback"
  end

  private

  attr_reader :app
end
