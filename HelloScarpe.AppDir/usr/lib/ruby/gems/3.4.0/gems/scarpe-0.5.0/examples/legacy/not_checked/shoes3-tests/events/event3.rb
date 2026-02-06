Shoes.app do  
  #puts "ARGV #{ARGV}"
  script_path = ""
  if ARGV.length > 1
     tp = ARGV[1]
     if tp[0] != '/'
       script_path = "#{DIR}/#{tp}"
     else
       script_path = tp
     end
    $stderr.puts "script is: #{script_path}"
  end
  
  handler = proc do |evt|
    $stderr.puts "event handler2 with #{evt.type}"
      evt.accept = $ck.checked?
  end
  
  stack do
    tagline "Manage events for a Shoes app"
    para "Run this app:"
    flow do
      @el = edit_line width: 500
      @el.text = script_path
      button "Select" do
        script_path = ask_open_file
        @el.text = script_path if script_path
      end
    end
    flow do
      $ck = check checked: true; para "Pass clicks?"
    end
    flow do 
      button "Load and control" do
        eval IO.read("#{script_path}").force_encoding("UTF-8"), TOPLEVEL_BINDING
        w = Shoes.APPS[-1]
        x = w.left
        y = w.top
        w.move x+80, y+40
        w.event = handler
      end
    end
  end
end
