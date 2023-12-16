# frozen_string_literal: true

require_relative "../test_helper"

class TestCalziniTextDrawables < Minitest::Test
  def setup
    @calzini = CalziniRenderer.new
  end

  def test_link_simple
    assert_equal %{<a id="elt-1" href="https://google.com">click here</a>},
      @calzini.render("link", { "click" => "https://google.com", "text" => "click here" })
  end

  def test_link_block
    assert_equal %{<a id="elt-1" onclick="handle('click')">click here</a>},
      @calzini.render("link", { "has_block" => true, "text" => "click here" })
  end

  def test_span_simple
    assert_equal %{<span id="elt-1" style="color:red;font-size:48px;font-family:Lucida">big red</span>},
      @calzini.render("span", { "stroke" => "red", "size" => :banner, "font" => "Lucida" }) { "big red" }
  end

  def test_code_simple
    assert_equal %{<code>Hello</code>}, @calzini.render("code", {}) { "Hello" }
  end

  def test_em_simple
    assert_equal %{<em>Hello</em>}, @calzini.render("em", {}) { "Hello" }
  end

  def test_strong_simple
    assert_equal %{<strong>Hello</strong>}, @calzini.render("strong", {}) { "Hello" }
  end
end
