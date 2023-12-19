# frozen_string_literal: true

require_relative "../test_helper"

class TestCalziniTextDrawables < Minitest::Test
  def setup
    @calzini = CalziniRenderer.new
  end

  def trim_html_ids(s)
    s.gsub(/ class="id_\d+"/, "")
  end

  def test_text_only_drawable
    assert_equal %{this is text},
      @calzini.render("text_drawable", ["this ", "is", " text"])
  end

  def test_simple_text_drawable_with_em
    assert_equal %{this <em class="id_1">is</em> text},
      @calzini.render("text_drawable",
        ["this ", { tag: "em", html_id: "1", items: ["is"], props: {}}, " text"])
  end

  # Span doesn't have default properties, so it's good for testing how a property is rendered
  def test_simple_text_drawable_with_span_styles
    assert_equal %{this <span style="color:#FF00FF;background-color:#0000FF;font-size:13px;font-family:Lucida">is</span> text},
      trim_html_ids(@calzini.render("text_drawable",
        ["this ", {
          tag: "span",
          html_id: "1",
          items: ["is"],
          props: {
            "font" => "Lucida",
            "size" => 13,
            "stroke" => "#FF00FF",
            "fill" => "#0000FF"
          }
        }, " text"]))
  end

  def test_link_with_has_block
    assert_equal %{this <a onclick="handle('click')">is</a> text},
      trim_html_ids(@calzini.render("text_drawable",
        ["this ", {
          tag: "a",
          html_id: "1",
          items: ["is"],
          props: {
            "has_block" => true,
          }
        }, " text"]))
  end

  def test_link_with_click
    assert_equal %{this <a href="#" onclick="handle('click')">is</a> text},
      trim_html_ids(@calzini.render("text_drawable",
        ["this ", {
          tag: "a",
          html_id: "1",
          items: ["is"],
          props: {
            "has_block" => true,
            "click" => "#",
          }
        }, " text"]))
  end

  def test_del_tag
    assert_equal %{this <del>is</del> text},
      trim_html_ids(@calzini.render("text_drawable",
        ["this ", {
          tag: "del",
          html_id: "1",
          items: ["is"],
          props: {
          }
        }, " text"]))
  end

  def test_single_strikethrough
    assert_equal %{this <span style="text-decoration-line:line-through">is</span> text},
      trim_html_ids(@calzini.render("text_drawable",
        ["this ", {
          tag: "span",
          html_id: "1",
          items: ["is"],
          props: {
            "strikethrough" => "single",
          }
        }, " text"]))
  end

  def test_single_strikethrough_none
    assert_equal %{this <span>is</span> text},
      trim_html_ids(@calzini.render("text_drawable",
        ["this ", {
          tag: "span",
          html_id: "1",
          items: ["is"],
          props: {
            "strikethrough" => "none",
          }
        }, " text"]))
  end
end
