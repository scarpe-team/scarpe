Shoes.app do  
  stack do
    tagline "Manage clicks for second Window"
    para "Demonstrates communication with second app"
    flow do
      @el = edit_line width: 450
      @el.text = "#{DIR}/samples/simple/chipmunk.rb"
      button "select app" do
        path = ask_file_open
        @el.text = path if path
      end
    end
    flow do
      $ck = check checked: true; para "Pass clicks?"
    end
    flow do 
      button "Start app with handler for it" do
        eval IO.read(@el.text).force_encoding("UTF-8"), TOPLEVEL_BINDING, @el.text
        w2 = Shoes.APPS[-1]
        x = w2.left
        y = w2.top
        w2.move x+80, y-40
        w2.event = proc do |evt|
          case evt.type
          when :click
            $stderr.puts "click handler2 with #{evt.type}"
            evt.accept = $ck.checked?
          else
            evt.accept = true
          end
        end
      end
    end
  end
=begin
  # 2nd App
  eval IO.read("#{DIR}/samples/simple/chipmunk.rb").force_encoding("UTF-8"), TOPLEVEL_BINDING
  start do
    # move the frontmost app (#2) left and up - it flickers. 
    w = Shoes.APPS[-1]
    x = app.left
    y = app.top
    w.move x+80, y-40
  end
=end
end
