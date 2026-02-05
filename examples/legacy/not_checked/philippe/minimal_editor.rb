# Minimal editor to test Para cursor system (like HH Editor)
# Tests: cursor positioning, marker (selection), hit testing, keypress

Shoes.app(title: "Minimal Editor", width: 600, height: 400) do
  background "#2d2d2d"
  
  @text = "Hello, this is a test.\nLine two here.\nAnd line three."
  @cursor_pos = 0
  
  stack margin: 10 do
    para "Minimal Editor Test (click to position cursor, type to insert)", 
         stroke: white, size: 12
    
    flow do
      para "Cursor: ", stroke: "#888", size: 10
      @cursor_label = para "0", stroke: "#0f0", size: 10
      para "  Marker: ", stroke: "#888", size: 10
      @marker_label = para "nil", stroke: "#0f0", size: 10
      para "  Selection: ", stroke: "#888", size: 10
      @selection_label = para "[]", stroke: "#0f0", size: 10
    end
  end
  
  stack margin: 10, width: 1.0, height: -80 do
    background "#1a1a1a"
    
    @editor = para @text, font: "Liberation Mono", size: 14,
                          stroke: "#ddd", margin: 10
    @editor.cursor = 0
  end
  
  # Click to position cursor
  click do |btn, x, y|
    c = @editor.hit(x, y)
    if c
      @editor.marker = nil  # clear selection
      @editor.cursor = c
      update_labels
    end
  end
  
  # Motion with mouse button held = selection
  @clicking = false
  motion do |x, y|
    if self.mouse[0] == 1
      c = @editor.hit(x, y)
      if c
        if @editor.marker.nil?
          @editor.marker = c
        else
          @editor.cursor = c
        end
        update_labels
      end
    end
  end
  
  release do
    @clicking = false
  end
  
  # Keypress for typing and navigation
  keypress do |k|
    case k
    when String
      # Insert character
      pos, len = @editor.highlight
      if len > 0
        @text[pos, len] = ""  # delete selection
        @editor.marker = nil
      end
      @text.insert(pos, k)
      @editor.cursor = pos + k.length
      @editor.replace(@text)
      update_labels
      
    when :backspace
      pos, len = @editor.highlight
      if len > 0
        @text[pos, len] = ""
        @editor.cursor = pos
      elsif pos > 0
        @text[pos-1, 1] = ""
        @editor.cursor = pos - 1
      end
      @editor.marker = nil
      @editor.replace(@text)
      update_labels
      
    when :delete
      pos, len = @editor.highlight
      len = 1 if len == 0
      @text[pos, len] = "" if pos < @text.length
      @editor.cursor = pos
      @editor.marker = nil
      @editor.replace(@text)
      update_labels
      
    when :left
      @editor.marker = nil
      @editor.cursor -= 1 if @editor.cursor > 0
      update_labels
      
    when :right
      @editor.marker = nil
      @editor.cursor += 1 if @editor.cursor < @text.length
      update_labels
      
    when :shift_left
      @editor.marker = @editor.cursor unless @editor.marker
      @editor.cursor -= 1 if @editor.cursor > 0
      update_labels
      
    when :shift_right
      @editor.marker = @editor.cursor unless @editor.marker
      @editor.cursor += 1 if @editor.cursor < @text.length
      update_labels
      
    when :control_a, :alt_a
      @editor.marker = 0
      @editor.cursor = @text.length
      update_labels
    end
  end
  
  def update_labels
    @cursor_label.replace(@editor.cursor.to_s)
    @marker_label.replace(@editor.marker.inspect)
    sel = @editor.highlight rescue [0, 0]
    @selection_label.replace(sel.inspect)
  end
end
