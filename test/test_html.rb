# frozen_string_literal: true

require "test_helper"

class TestHTML < Minitest::Test
  def test_works_for_pure_tags
    subject = ::Scarpe::HTML.render { |h| h.div { "foo" } }

    assert_equal "<div>foo</div>", subject
  end

  def test_works_for_classes
    subject = ::Scarpe::HTML.render { |h| h.div(class: "container") { "foo" } }

    assert_equal '<div class="container">foo</div>', subject
  end

  def test_works_for_style
    subject = ::Scarpe::HTML.render { |h| h.div(style: { display: "block", width: "100px" }) { "foo" } }

    assert_equal '<div style="display:block;width:100px">foo</div>', subject
  end

  def test_works_for_string_style
    subject = ::Scarpe::HTML.render { |h| h.div(style: "display:block;width:100px") { "foo" } }

    assert_equal '<div style="display:block;width:100px">foo</div>', subject
  end

  def test_works_with_multiple_children
    subject = ::Scarpe::HTML.render do |h|
      h.ul do
        h.li { "one" }
        h.li { "two" }
      end
    end

    assert_equal "<ul><li>one</li><li>two</li></ul>", subject
  end

  def test_works_with_void_tag
    subject = ::Scarpe::HTML.render { |h| h.input(type: "text") }

    assert_equal '<input type="text" />', subject

  end
end
