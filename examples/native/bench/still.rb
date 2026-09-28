# Nothing moves: the idle-CPU benchmark in native/PERF.md. An idle app should cost nothing.
Shoes.app(title: "Still", width: 600, height: 500) do
  background "#fbfbfd"
  stack(margin: 20) do
    title "A quiet app"
    para "Some text, a few controls, and no timers."
    edit_line("an input", width: 300)
    flow(margin_top: 10) do
      button "OK"
      check
      para "Remember me"
    end
    list_box(items: %w[one two three], choose: "two")
  end
end
