Shoes.app title: "Sleepless", width: 80, height: 120 do
  @push = button "☕️"
  @note = para "😪"
  @push.click {
    if @pid.nil?
      @pid = spawn("caffeinate -d")
      @note.replace "😳"
    else
      Process.kill 9, @pid
      @pid = nil
      @note.replace "😪"
    end
  }
end
