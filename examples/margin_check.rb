Shoes.app do
  background blue

  @stack1 = stack(width: 100, height: 100) do
    background red
    b = button("Push me", margin: [10, 25, 5, 10]) do
      alert "Aha! Click!"
    end
  end

  @stack1 = stack do
    background aquamarine
    b = button("Hash margin", margin: { left: 10, right: 5, top: 25, bottom: 10 }) do
      alert "Aha! Click!"
    end
  end

  stack(width: 100, height: 100) do
    background yellow
    button "Middle Button", margin: 5, margin_top: 30
  end

  @stack2 = stack(width: 100, height: 100) do
    background green
    button "OK 2"
  end
end
