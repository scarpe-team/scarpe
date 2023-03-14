# frozen_string_literal: true

require "test_helper"

# This method of testing starts up a Scarpe app with no display service
# that runs in the same process as the test.
class TestNoDisplayPara < Minitest::Test
  class << self
    attr_accessor :ret_val
  end

  def setup
    TestNoDisplayPara.ret_val = nil
  end

  def test_para_text_children
    test_scarpe_code_no_display(<<~'SCARPE_APP', <<~'TEST_CODE')
      Scarpe.app do
        para "Testing test test. ",
          "Breadsticks. ",
          "Breadsticks. ",
          "Breadsticks. ",
          "Very good."
      end
    SCARPE_APP
      the_app = self
      # During init, no widgets have yet been created. So that's too early to find our para.
      on_next_heartbeat do
        para = find_widgets_by(Scarpe::Para)[0]
        TestNoDisplayPara.ret_val = para.text_items
        the_app.destroy
      end
    TEST_CODE
    assert_equal ["Testing test test. ", "Breadsticks. ", "Breadsticks. ", "Breadsticks. ", "Very good."],
      TestNoDisplayPara.ret_val
  end

  def test_para_replace
    test_scarpe_code_no_display(<<~'SCARPE_APP', <<~'TEST_CODE')
      Scarpe.app do
        para 'hello world'
      end
    SCARPE_APP
      the_app = self
      # During init, no widgets have yet been created. So that's too early to find our para.
      on_next_heartbeat do
        para = find_widgets_by(Scarpe::Para)[0]
        para.replace("goodbye world")

        if para.text_items == ["goodbye world"]
          TestNoDisplayPara.ret_val = true
          the_app.destroy
        else
          raise "Expected para.text_children to equal ['goodbye world']!"
        end
      end
    TEST_CODE
    assert_equal true, TestNoDisplayPara.ret_val
  end
end

class TestWebviewPara < Minitest::Test
  def setup
    @default_properties = {
      "shoes_linkable_id" => 1,
      "text_items" => ["Hello World"],
      "stroke" => nil,
      "size" => :para,
      "html_attributes" => {},
    }
    Scarpe::DisplayService.full_reset!
  end

  def teardown
    Scarpe::DisplayService.full_reset!
  end

  def test_renders_paragraph
    para = Scarpe::WebviewPara.new(@default_properties.merge("text_items" => ["Hello World"]))
    html_id = para.html_id

    assert_html para.to_html, :p, id: html_id, style: "font-size:12px" do
      "Hello World"
    end
  end

  def test_renders_paragraph_with_collection_of_arguments
    items = [
      "Testing test test. ",
      "Breadsticks. ",
      "Breadsticks. ",
      "Breadsticks. ",
      "Very good.",
    ]
    para = Scarpe::WebviewPara.new(@default_properties.merge("text_items" => items))

    assert_html para.to_html, :p, id: para.html_id, style: "font-size:12px" do
      "Testing test test. Breadsticks. Breadsticks. Breadsticks. Very good."
    end
  end

  def test_renders_a_magenta_paragraph
    para = Scarpe::WebviewPara.new(@default_properties.merge("stroke" => "magenta"))

    assert_html para.to_html, :p, id: para.html_id, style: "color:magenta;font-size:12px" do
      "Hello World"
    end
  end

  # What do we do about HTML class attributes? I'm assuming that's not Shoes-standard...
  # def test_renders_a_blue_paragraph_with_class_attribute
  #   para = Scarpe::WebviewPara.new(@default_properties.merge("class" => "sea", "stroke" => "blue"))
  #
  #   assert_html para.to_html, :p, class: "sea", id: para.html_id, style: "color:blue;font-size:12px" do
  #     "Hello World"
  #   end
  # end

  def test_renders_paragraph_with_size_number
    para = Scarpe::WebviewPara.new(@default_properties.merge(
      "text_items" => ["Oh, to fling and be flung"],
      "size" => 48,
    ))

    assert_html para.to_html, :p, id: para.html_id, style: "font-size:48px" do
      "Oh, to fling and be flung"
    end
  end

  def test_renders_paragraph_with_size_symbol
    para = Scarpe::WebviewPara.new(@default_properties.merge(
      "text_items" => ["Oh, to fling and be flung"],
      "size" => :banner,
    ))

    assert_html para.to_html, :p, id: para.html_id, style: "font-size:48px" do
      "Oh, to fling and be flung"
    end
  end

  def test_replace_children
    para = Scarpe::WebviewPara.new(@default_properties.merge(
      "text_items" => ["Oh, to fling and be flung"],
      "size" => :banner,
    ))
    mocked_html_element = Minitest::Mock.new
    mocked_html_element.expect :inner_html=, nil, [String]
    para.stub :html_element, mocked_html_element do
      # We used 1 as the shoes_linkable_id in the properties data above
      para.send_shoes_event(
        { "text_items" => ["Oh, to be flung and to fling"] },
        event_name: "prop_change",
        target: 1,
      )

      assert_html para.to_html, :p, id: para.html_id, style: "font-size:48px" do
        "Oh, to be flung and to fling"
      end
    end
    mocked_html_element.verify
  end

  def test_children_can_be_text_widgets
    strong = Scarpe::WebviewStrong.new("content" => "I am strong", "shoes_linkable_id" => 2)
    para = Scarpe::WebviewPara.new(@default_properties.merge("text_items" => [strong]))
    para.stub :items_to_display_children, [strong], [2] do
      assert_html para.to_html, :p, id: para.html_id, style: "font-size:12px" do
        strong.to_html
      end
    end
  end

  def test_can_replace_widgets_with_other_widgets
    strong = Scarpe::WebviewStrong.new("content" => "I am strong", "shoes_linkable_id" => 2)
    em = Scarpe::WebviewEm.new("content" => "I am em", "shoes_linkable_id" => 3)
    para = Scarpe::WebviewPara.new(@default_properties.merge("text_items" => [strong]))
    mocked_html_element = Minitest::Mock.new
    mocked_html_element.expect :inner_html=, nil, [String]

    para.stub :html_element, mocked_html_element do
      para.stub :items_to_display_children, [em], [3] do
        # Linkable id 3 is em
        para.send_shoes_event({ "text_items" => [3] }, event_name: "prop_change", target: 1)
        assert_html para.to_html, :p, id: para.html_id, style: "font-size:12px" do
          em.to_html
        end
      end
    end
    mocked_html_element.verify
  end
end
