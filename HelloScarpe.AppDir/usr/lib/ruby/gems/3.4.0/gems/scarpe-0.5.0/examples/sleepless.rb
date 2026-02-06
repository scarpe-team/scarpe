Shoes.app title: "Sleepless", width: 80, height: 120 do
  @push = button "☕️"
  @note = para "😪"
  @push.click {
    if @pid.nil?
      if RUBY_PLATFORM =~ /darwin/
        @pid = spawn("caffeinate -d")
      elsif RUBY_PLATFORM =~ /linux/
        @pid = spawn("xset s off -dpms")
      elsif RUBY_PLATFORM =~ /win32|win64|\.NET/
        @pid = spawn("powercfg -change -monitor-timeout-ac 0")
      end
      @note.replace "😳"
    else
      if RUBY_PLATFORM =~ /darwin/
        system("kill #{@pid}")
      elsif RUBY_PLATFORM =~ /linux/
        system("kill -9 #{@pid}")
      elsif RUBY_PLATFORM =~ /win32|win64|\.NET/
        system("taskkill /pid #{@pid} /f")
      end
      @pid = nil
      @note.replace "😪"
    end
  }
end
