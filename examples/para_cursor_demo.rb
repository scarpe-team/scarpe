# Para Cursor Demo — exercises the new text cursor/marker/hit system
#
# This demonstrates the Shoes3 Para cursor system in Scarpe:
# - para.cursor = n (set text cursor position)
# - para.marker = n (set selection anchor)
# - para.highlight (get [pos, len] of selection)
# - para.hit(x, y) (hit-test: character at pixel coordinates)
# - para.cursor_top (y-coordinate of cursor)
#
# Run: bundle exec ruby exe/scarpe --dev examples/para_cursor_demo.rb

Shoes.app(title: "Para Cursor Demo", width: 500, height: 400) do
  background "#f0f0f0"

  stack margin: 15 do
    title "Para Cursor Demo", size: 18

    @text = "The quick brown fox jumps over the lazy dog. Click anywhere in this text to place the cursor."

    stack margin_top: 10 do
      background white
      @code_para = para @text, font: "Liberation Mono", size: 14,
                                stroke: "#333", wrap: "trim"
      @code_para.cursor = 0
    end

    @info = para "Cursor: 0 | Marker: none | Hit: none", size: 10, stroke: "#666", margin_top: 10

    flow margin_top: 10 do
      button "Select 'brown fox'" do
        @code_para.marker = 10
        @code_para.cursor = 19
        update_info
      end

      button "Select all" do
        @code_para.marker = 0
        @code_para.cursor = @text.length
        update_info
      end

      button "Clear selection" do
        @code_para.marker = nil
        update_info
      end
    end

    flow margin_top: 5 do
      button "Cursor to start" do
        @code_para.cursor = 0
        @code_para.marker = nil
        update_info
      end

      button "Cursor to end" do
        @code_para.cursor = @text.length
        @code_para.marker = nil
        update_info
      end

      button "Cursor to 20" do
        @code_para.cursor = 20
        @code_para.marker = nil
        update_info
      end
    end

    # Click to place cursor
    click do |_, x, y|
      c = @code_para.hit(x, y)
      if c
        @code_para.marker = nil
        @code_para.cursor = c
        update_info
      end
    end

    # Drag to select
    motion do |x, y|
      if self.mouse[0] == 1
        c = @code_para.hit(x, y)
        if c
          @code_para.marker = @code_para.cursor if @code_para.marker.nil?
          @code_para.cursor = c
          update_info
        end
      end
    end
  end
end

def update_info
  sel = @code_para.highlight
  hit_val = @code_para.hit(0, 0)
  @info.replace "Cursor: #{@code_para.cursor} | Marker: #{@code_para.marker || 'none'} | " \
                "Selection: [#{sel[0]}, #{sel[1]}] | cursor_top: #{@code_para.cursor_top}"
end
