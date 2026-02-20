# frozen_string_literal: true

require_relative "../test_helper"

class TestCalziniSlots < Minitest::Test
  def setup
    @calzini = CalziniRenderer.new
    # Base flexbox styles (position:relative is added LAST by Calzini for child positioning)
    @stack_base = %{display:flex;flex-direction:column;align-content:flex-start;justify-content:flex-start;align-items:flex-start}
    @flow_base = %{display:flex;flex-direction:row;flex-wrap:wrap;align-content:flex-start;justify-content:flex-start;align-items:flex-start}
    # Full default style (for simple tests with no additional styles)
    @stack_default_style = "#{@stack_base};position:relative"
    @flow_default_style = "#{@flow_base};position:relative"
    # Stack inner div (no display:contents)
    @stack_inner_div_tag = %{<div style="height:100%;width:100%;position:relative">}
    # Flow/DocumentRoot inner div (has display:contents for proper flex-wrap)
    @flow_inner_div_tag = %{<div style="height:100%;width:100%;position:relative;display:contents">}
  end

  def test_stack_simple
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_default_style}">} +
      %{#{@stack_inner_div_tag}contents</div></div>},
      @calzini.render("stack", {}) { "contents" }
  end

  def test_flow_simple
    assert_equal %{<div id="elt-1" } +
      %{style="#{@flow_default_style}">} +
      %{#{@flow_inner_div_tag}contents</div></div>},
      @calzini.render("flow", {}) { "contents" }
  end

  def test_docroot_simple
    assert_equal %{<div id="elt-1" } +
      %{style="#{@flow_default_style}">} +
      %{#{@flow_inner_div_tag}contents</div></div>},
      @calzini.render("documentroot", {}) { "contents" }
  end

  def test_stack_border_plain_color
    # Note: position:relative is added LAST by Calzini
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_base};border-style:solid;border-width:1px;border-radius:0px;border-color:red;position:relative">} +
      %{#{@stack_inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "border_color" => "red" }) { "contents" }
  end

  def test_stack_border_gradient
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_base};border-style:solid;border-width:1px;border-radius:0px;border-image:linear-gradient(45deg, red, green);position:relative">} +
      %{#{@stack_inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "border_color" => ("red".."green") }) { "contents" }
  end

  def test_stack_border_rgba
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_base};border-style:solid;border-width:1px;border-radius:0px;border-color:rgba(1.0, 0.0, 0.0, 1.0);position:relative">} +
      %{#{@stack_inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "border_color" => [1.0, 0.0, 0.0, 1.0] }) { "contents" }
  end

  def test_stack_border_attrs
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_base};border-style:solid;border-width:3px;border-radius:2px;border-color:red;position:relative">} +
      %{#{@stack_inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "border_color" => "red", "options" => { "strokewidth" => 3, "curve" => 2 } }) { "contents" }
  end


  def test_stack_padding
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_base};padding:25px;position:relative">} +
      %{#{@stack_inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "padding" => 25 }) { "contents" }
  end

  def test_stack_options_padding
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_base};padding:15px;position:relative">} +
      %{#{@stack_inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "options" => { "padding" => 15 } }) { "contents" }
  end

  def test_stack_padding_overrides_options
    assert_equal %{<div id="elt-1" } +
      %{style="#{@stack_base};padding:25px;position:relative">} +
      %{#{@stack_inner_div_tag}contents</div></div>},
      @calzini.render("stack", { "padding" => 25, "options" => { "padding" => 15 } }) { "contents" }
  end

 
end
