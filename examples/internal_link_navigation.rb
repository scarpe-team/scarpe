# Test for internal link navigation (issue #569)
# link(click: "/path") should trigger visit() internally

Shoes.app width: 400, height: 300, title: "Internal Link Test" do
  page(:index) do
    title "Page 1"
    para "This is the first page."
    para link("Go to Page 2", click: "/page2")
  end

  page(:page2) do
    title "Page 2"
    para "You navigated here internally!"
    para link("Back to Page 1", click: "/index")
  end

  # Start on the index page
  visit(:index)
end
