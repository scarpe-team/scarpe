require 'shoes'

Shoes.app(title: "Shoes App Example", width: 400, height: 600) do
  background darkblue
  fill white

  stack do
    banner "Welcome to Shoes App!" do |b|
      @banner = b
    end

    flow do
      para "View the full collection of "
      link("shoes") { alert "Shoes Collection: shoesrb.com" }
      para " online!"
    end

    image "shoe-image.jpg", width: 200, height: 200

    stack(margin: 12) do
      para "Click the button to refresh the banner text:"
      button "Refresh Banner" do
        @banner.text = "Shoes App Reloaded"
      end
    end
  end
end
