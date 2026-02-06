Shoes.app do
  @time = title "0:00"
  every 1 do
    @time.replace(Time.now.strftime("%I:%M %p"))
  end
end
