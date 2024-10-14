Shoes.app(title: "Page Navigation Example", width: 300, height: 200) do
  style(Shoes::Para, size: 10)
  style(Shoes::Button, width: 80)

  page(:home) do
    title "Home Page"
    background "#f0f0f0"
    para "Welcome to the page navigation example!"
    button "Go to Razzmatazz" do
      visit(:razzmatazz)
    end
    button "Go to FlooperLand" do
      visit(:flooperland)
    end
  end

  page(:razzmatazz) do
    title "Razzmatazz"
    background "#DFA5A5"
    para "This is Razzmatazz"
    button "Go Home" do
      visit(:home)
    end
    button "Go to FlooperLand" do
      visit(:flooperland)
    end
  end

  page(:flooperland) do
    title "FlooperLand"
    background "#A5DFA5"
    para "This is FlooperLand"
    button "Go Home" do
      visit(:home)
    end
    button "Go to Razzmatazz" do
      visit(:razzmatazz)
    end
  end

  visit(:home)  # Start at the home page
end
