Shoes.app do

  event do |evt|
    # do not trigger new events here unless you can handle them recursively
    # which is harder than you think. 
    case evt.type
    when :click 
      $stderr.puts "click handler called: #{evt.type} #{evt.button}, #{evt.x} #{evt.y} #{evt.modifiers}"
      evt.accept = true
    when :keypress
      $stderr.puts "keypress: #{evt.key}"
      evt.accept = true
    when :keydown
      $stderr.puts "keydown for #{evt.key}"
      evt.accept = $ck.checked? 
    when :keyup
      $stderr.puts "keyup for #{evt.key}"
      evt.accept = $ck.checked? 
    when :motion
      evt.accept = false
    when :release
      evt.accept = false
    when :wheel 
      $stderr.puts "wheel handler called: #{evt.type} #{evt.button}, #{evt.x} #{evt.y} #{evt.modifiers}"
      evt.accept = true
    else
      puts "Other: #{evt.type.inspect}"
      evt.accept = true
    end
  end  

  stack do
    para "Key Tests"
    flow do
      $ck = check checked: true; para "Enable up/down"
    end
    @eb = edit_box width: 500, height: 350
  end
  keypress do |key|
    @eb.append "press: #{key}\n"
  end
  keyup do |key| 
    @eb.append "up: #{key}\n"
  end
  keydown do |key| 
    @eb.append "down: #{key}\n"
  end
  wheel do |d, x, y, mods|
    @eb.append "wheel dir: #{d} at #{x},#{y}, with #{mods}\n"
  end
end
