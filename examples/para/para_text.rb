Shoes.app do
  stack do
    @note = para " your note will appear here"

    @edit_box = edit_box ""
    @save_button = button "Save"

    @save_button.click do
      new_text = @edit_box.text
      @note.text = new_text
      alert("Note saved successfully!")
    end
  end
end
