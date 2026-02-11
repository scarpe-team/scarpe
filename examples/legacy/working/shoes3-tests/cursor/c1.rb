Shoes.app do
  stack do
    para "Change cursor to"
    flow do
      button "arrow" do
        app.cursor = :arrow_cursor
      end
      button "text" do
        app.cursor = :text_cursor
      end
      button "watch" do
        app.cursor = :watch_cursor
      end
      button "hand" do
        app.cursor = :hand_cursor
      end
    end
    para "app is #{app.class}"
    para "Cursor is #{app.cursor.inspect}"
  end
end
