Shoes.app do
  stack :width => 120 do
    @b = button "Click me", :width => "100%" do
      alert "button.width = #{@b.width}\n" +
        "button.style[:width] = #{@b.style[:width]}"
    end
  end
end
