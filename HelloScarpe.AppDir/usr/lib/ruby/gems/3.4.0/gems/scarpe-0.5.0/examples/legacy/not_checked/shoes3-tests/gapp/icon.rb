Shoes.app do
 stack do
    para "Icon setting tests"
    st = Shoes.settings
    default = st.icon_path
    para "Settings path is #{st.icon_path} "
    button "Show Default icon" do
      @pnl.clear do
        image "#{DIR}/#{st.icon_path}"
      end
    end
    para "Must be relative to #{DIR}"
    flow do
      button "Set default" do
        fp = ask_open_file
        str = fp[DIR.length+1..-1]
        @el1.text = str
      end
      @el1 = edit_line
      button "Test" do
        @pnl.clear do
          image "#{DIR}/#{@el1.text}"
        end
        st.icon_path = @el1.text
        window do
          para "What icon did you expect?"
        end
      end
      button "restore" do
        st.icon_path = default
        @pnl.clear do
          image "#{DIR}/#{st.icon_path}"
        end
      end
    end
    para "app.window_set_icon_path - try ABS path"
    flow do
      @el2 = edit_line
      button "select" do
        fp = ask_open_file
        @el2.text = fp
      end
      button "test" do
        @pnl.clear do
          image @el2.text
        end
        app.set_window_icon_path @el2.text
        window do
          para "Is that the icon you expected"
        end
       end
    end
  end 
  @pnl = stack do
  end
end
