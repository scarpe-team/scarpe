# A small form: the keystroke-to-pixels benchmark in native/PERF.md types into the edit_line
# and times each key until the frame that shows it reaches the screen.
Shoes.app(title: "Typing", width: 600, height: 500) do
  background "#fbfbfd"
  stack(margin: 20) do
    title "Sign the guestbook"
    para "Your name:"
    @name = edit_line(width: 320)
    @greeting = para "Hello, stranger."
    para "Every key you type updates the greeting below the field, the way a real form reacts."
    flow(margin_top: 10) do
      button "Save"
      button "Cancel"
    end
  end
  @name.change { @greeting.text = "Hello, #{@name.text}." }
end
