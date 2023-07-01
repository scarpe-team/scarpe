Shoes.app do
    @push = button "Push me"
    @note = para "Nothing pushed so far"
    @push.click {
      @note.change_style(
 
   
        "font-size": "20px",
        "color": "#ff0000"
        

   
      )
    }
  end
  