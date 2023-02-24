# frozen_string_literal: true

require "test_helper"

# Going to need to rewrite this, or at a minimum heavily modify it :-(
__END__

class TestEditBox < Minitest::Test
  def setup
    app = Minitest::Mock.new
    Scarpe::Widget.document_root = app
    app.expect :bind, nil, [Object]
  end

  def test_renders_textarea
    edit_box = Scarpe::EditBox.new("Hello, World!")
    html_id = edit_box.html_id

    assert_html edit_box.to_html, :textarea, id: html_id, oninput: "scarpeHandler('#{html_id}-change', this.value)" do
      "Hello, World!"
    end
  end

  def test_renders_textarea_content_block
    edit_box = Scarpe::EditBox.new { "Hello, World!" }
    html_id = edit_box.html_id

    assert_html edit_box.to_html, :textarea, id: html_id, oninput: "scarpeHandler('#{html_id}-change', this.value)" do
      "Hello, World!"
    end
  end

  def test_textarea_width
    edit_box = Scarpe::EditBox.new("Hello, World!", width: 100)
    html_id = edit_box.html_id

    assert_html edit_box.to_html,
      :textarea,
      id: html_id,
      oninput: "scarpeHandler('#{html_id}-change', this.value)\" style=\"width:100px" do
      "Hello, World!"
    end
  end

  def test_textarea_height
    edit_box = Scarpe::EditBox.new("Hello, World!", height: 100)
    html_id = edit_box.html_id

    assert_html edit_box.to_html,
      :textarea,
      id: html_id,
      oninput: "scarpeHandler('#{html_id}-change', this.value)\" style=\"height:100px" do
      "Hello, World!"
    end
  end

  def test_textarea_change_callback
    puts "TODO: test_textarea_change_callback"
  end

  private

  attr_reader :app
end
