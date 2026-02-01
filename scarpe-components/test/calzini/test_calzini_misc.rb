# frozen_string_literal: true

require_relative "../test_helper"

class TestCalziniMiscDrawables < Minitest::Test
  def setup
    @calzini = CalziniRenderer.new
  end

  def test_checkbox_checked
    assert_equal %{<input type="checkbox" id="elt-1" onclick="handle('click')" value="done?" checked="true" />},
      @calzini.render("check", { "text" => "done?", "checked" => true })
  end

  def test_checkbox_unchecked
    assert_equal %{<input type="checkbox" id="elt-1" onclick="handle('click')" value="done?" checked="false" />},
      @calzini.render("check", { "text" => "done?", "checked" => false })
  end

  def test_checkbox_hidden
    assert_equal %{<input type="checkbox" id="elt-1" onclick="handle('click')" value="done?" checked="true" style="display:none" />},
      @calzini.render("check", { "text" => "done?", "checked" => true, "hidden" => true })
  end

  def test_edit_box_default
    assert_equal %{<textarea id="elt-1" oninput="handle('change', this.value)" onmouseover="handle('hover')"></textarea>},
      @calzini.render("edit_box", {})
  end

  def test_edit_box_hidden
    assert_equal %{<textarea id="elt-1" oninput="handle('change', this.value)" onmouseover="handle('hover')" style="display:none"></textarea>},
      @calzini.render("edit_box", { "hidden" => true })
  end

  def test_edit_box_simple
    assert_equal %{<textarea id="elt-1" oninput="handle('change', this.value)" onmouseover="handle('hover')" style="width:75;height:50">default</textarea>},
      @calzini.render("edit_box", { "height" => "50", "width" => "75", "text" => "default" })
  end

  def test_edit_line_default
    assert_equal %{<input id="elt-1" type="text" oninput="handle('change', this.value)" onmouseover="handle('hover')" style="font:;color:" />},
      @calzini.render("edit_line", {})
  end

  def test_edit_line_hidden
    assert_equal %{<input id="elt-1" type="text" oninput="handle('change', this.value)" onmouseover="handle('hover')" style="display:none;font:;color:" />},
      @calzini.render("edit_line", { "hidden" => true })
  end

  def test_edit_line_simple
    assert_equal %{<input id="elt-1" type="text" oninput="handle('change', this.value)" onmouseover="handle('hover')" value="(default)" style="width:200;font:;color:" />},
      @calzini.render("edit_line", { "width" => "200", "text" => "(default)" })
  end

  def test_image_simple
    assert_equal %{<img id="elt-1" src="https://example.com/example.png" />},
      @calzini.render("image", { "url" => "https://example.com/example.png" })
  end

  def test_image_with_click
    assert_equal %{<a id="elt-1" href="https://google.com"><img id="elt-1" src="https://example.com/example.png" style="width:150;height:200" /></a>},
      @calzini.render("image", { "url" => "https://example.com/example.png", "height" => "200", "width" => "150", "click" => "https://google.com" })
  end

  def test_image_with_abs_positioning
    assert_equal %{<img id="elt-1" src="https://example.com/example.png" style="position:absolute;top:15;left:20;width:150;height:200" />},
      @calzini.render("image", { "url" => "https://example.com/example.png", "height" => "200", "width" => "150", "top" => "15", "left" => "20" })
  end

  def test_list_box_empty
    assert_equal %{<select id="elt-1" onchange="handle('change', this.options[this.selectedIndex].value)"></select>},
      @calzini.render("list_box", {})
  end

  def test_list_box_simple
    assert_equal %{<select id="elt-1" onchange="handle('change', this.options[this.selectedIndex].value)"} +
      %{ style="width:150;height:75"><option value="dog">dog</option>} +
      %{<option value="cat" selected="true">cat</option><option value="bird">bird</option></select>},
      @calzini.render("list_box", { "height" => "75", "width" => "150", "items" => ["dog", "cat", "bird"], "choose" => "cat" })
  end

  def test_list_box_none_selected
    assert_equal %{<select id="elt-1" onchange="handle('change', this.options[this.selectedIndex].value)"} +
      %{ style="width:150;height:75"><option value="dog">dog</option>} +
      %{<option value="cat">cat</option><option value="bird">bird</option></select>},
      @calzini.render("list_box", { "height" => "75", "width" => "150", "items" => ["dog", "cat", "bird"] })
  end

  def test_list_box_just_items
    assert_equal %{<select id="elt-1" onchange="handle('change', this.options[this.selectedIndex].value)">} +
      %{<option value="dog">dog</option>} +
      %{<option value="cat">cat</option><option value="bird">bird</option></select>},
      @calzini.render("list_box", { "items" => ["dog", "cat", "bird"] })
  end

  def test_radio_minimal
    assert_equal %{<input type="radio" id="elt-1" onclick="handle('click')" name="no_group" />},
      @calzini.render("radio", {})
  end

  def test_radio_group
    assert_equal %{<input type="radio" id="elt-1" onclick="handle('click')" name="boba" />},
      @calzini.render("radio", { "group" => "boba" })
  end

  def test_radio_checked
    assert_equal %{<input type="radio" id="elt-1" onclick="handle('click')" name="boba" checked="true" />},
      @calzini.render("radio", { "group" => "boba", "checked" => true })
  end

  def test_video_simple
    assert_equal %{<video id="elt-1" controls="true"><source type="video/mp4" /></video>},
      @calzini.render("video", { "url" => "http://techslides.com/demos/sample-videos/small.mp4", "format" => "video/mp4" })
  end
end
