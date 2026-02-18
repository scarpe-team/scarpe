Shoes.app do
 stack do
    para "Title and app name tests"
    st = Shoes.settings
    para "settings name is #{st.app_name} vs #{app.name}"
    flow do
      @el1 = edit_line width: 100, border: 3
      button "name =" do
        app.name = @el1.text
        para "settings name is #{st.app_name} vs #{app.name} did title change?"
      end
    end
    flow do
      @el2 = edit_line width: 100, border: 3
      button "app_name =" do
        st.app_name = @el2.text
        window do
          para "only affect new windows?"
        end
        para "settings name is #{st.app_name} vs #{app.name} did title change?"
      end
    end
    flow do 
      @el3 = edit_line width: 100, margin: 3
      button "wtitle =" do
        app.set_window_title @el3.text
        window do
          para "only affect new windows?"
        end
        para "settings name is #{st.app_name} vs #{app.name} did title change?"
      end
    end
  end
end
