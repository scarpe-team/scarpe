require 'yaml'
Shoes.app do  
  yaml_path = ""
  if ARGV.length > 1
     tp = ARGV[1]
     if tp[0] != '/'
       yaml_path = "#{DIR}/../#{tp}"
     else
       yaml_path = tp
     end
  end
  stack do
    tagline "Replay Clicks for another app"
    para "Load events from"
    flow do 
      @sv = edit_line width: 450
      @sv.text = yaml_path
      button "Change" do
        path = ask_open_file
        @sv.text = path if path
      end
    end

    flow do
      button "Start App" do
        evtflhash = YAML::load_file(@sv.text)
        hdr = evtflhash[:context]
        puts hdr
        script = hdr[:app]
        eval IO.read(script).force_encoding("UTF-8"), TOPLEVEL_BINDING, script
        w2 = Shoes.APPS[-1]
        x = w2.left
        y = w2.top
        w2.move x+80, y-40
        @events = evtflhash[:events]
        #puts @events
      end
    end
    button "Replay Events" do
     # note this creates as many simulaneous timers as events
     # not pretty
      w2 = Shoes.APPS[-1]
      base_t = nil
      @events.each_index do |r|
        ev = @events[r]
        if r == 0 
          # chop first delay - minor improvement
          base_t = ev[:time]
          puts "base_t #{base_t}"
        end
        t = ev[:time]
        timer(t-base_t) do
          puts "wait for #{t-base_t}"
          puts "  move to #{ev[:x]}, #{ev[:y]} and click "
          w2.replay_event(ev)
        end
      end
    end
  end
end
