# Test dynamic window title changes
Shoes.app(title: "Original Title", width: 350, height: 200) do
  stack margin: 10 do
    para "Click buttons to change window title:"
    
    @count = 0
    
    button "Title 1" do
      app.title = "First Title"
    end
    
    button "Title 2" do
      app.set_window_title("Second Title")
    end
    
    button "Counter Title" do
      @count += 1
      app.title = "Clicked #{@count} times"
    end
    
    @el = edit_line width: 200
    button "Custom Title" do
      app.title = @el.text unless @el.text.empty?
    end
  end
end
