# frozen_string_literal: true

require_relative "../test_helper"

class TestCalziniSlots < Minitest::Test
  def setup
    @calzini = CalziniRenderer.new
    @stack_default_style = %{display:flex;flex-direction:column;align-content:flex-start;justify-content:flex-start;align-items:flex-start}
    @flow_default_style = %{display:flex;flex-direction:row;flex-wrap:wrap;align-content:flex-start;justify-content:flex-start;align-items:flex-start}
    @inner_div_tag = %{<div style="height:100%;width:100%;position:relative">}
  end

  def test_stack_simple
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style}">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", {}) { "contents" }
  end

  def test_flow_simple
    assert_equal %{<div id="elt-1" } +
      %{style="#{@flow_default_style}">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("flow", {}) { "contents" }
  end

  def test_docroot_simple
    assert_equal %{<div id="elt-1" } +
      %{style="#{@flow_default_style}">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("documentroot", {}) { "contents" }
  end

  def test_stack_border_plain_color
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};border-style:solid;border-width:1px;border-radius:0px;border-color:red">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "border_color" => "red" }) { "contents" }
  end

  def test_stack_border_gradient
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};border-style:solid;border-width:1px;border-radius:0px;border-image:linear-gradient(45deg, red, green)">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "border_color" => ("red".."green") }) { "contents" }
  end

  def test_stack_border_rgba
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};border-style:solid;border-width:1px;border-radius:0px;border-color:rgba(1.0, 0.0, 0.0, 1.0)">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "border_color" => [1.0, 0.0, 0.0, 1.0] }) { "contents" }
  end

  def test_stack_border_attrs
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};border-style:solid;border-width:3px;border-radius:2px;border-color:red">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "border_color" => "red", "options" => { "strokewidth" => 3, "curve" => 2 } }) { "contents" }
  end

  def test_stack_margin
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};margin:25px">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "margin" => 25 }) { "contents" }
  end

  def test_stack_options_margin
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};margin:15px">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "options" => { "margin" => 15 } }) { "contents" }
  end

  def test_stack_margin_overrides_options
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};margin:25px">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "margin" => 25, "options" => { "margin" => 15 } }) { "contents" }
  end

  def test_stack_padding
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};padding:25px">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "padding" => 25 }) { "contents" }
  end

  def test_stack_options_padding
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};padding:15px">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "options" => { "padding" => 15 } }) { "contents" }
  end

  def test_stack_padding_overrides_options
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};padding:25px">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "padding" => 25, "options" => { "padding" => 15 } }) { "contents" }
  end

  def test_stack_options_hash_margin
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};margin-left:5px;margin-right:10px;margin-top:15px;margin-bottom:20px">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "margin" => { left: 5, right: 10, top: 15, bottom: 20 } }) { "contents" }
  end

  def test_stack_options_array_margin
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};margin-left:5px;margin-right:10px;margin-top:15px;margin-bottom:20px">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "margin" => [5, 10, 15, 20] }) { "contents" }
  end

  def test_stack_options_margin_left_overrides_options
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};margin-left:25px">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "margin_left" => 25, "options" => { "margin" => 15 } }) { "contents" }
  end

  def test_stack_margin_left_overrides_margin
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style};margin:25px;margin-left:15px">} +
      %{#{@inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "margin" => 25, "margin_left" => 15 }) { "contents" }
  end
end
