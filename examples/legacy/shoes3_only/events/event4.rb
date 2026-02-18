class TestWidget < Shoes::Widget

    attr_accessor :click_blk
    
    def initialize(&blk)
        @click_blk = blk 
        self.width = 200; self.height = 200 ## note that you do need this
        flow width: 190, height: 200 do   ###### explicit slot
            background coral
            para "user defined widget"
        end 
    end
    
    def click(btn,x,y,mods)
      puts "TW click called, sending.."
      @click_blk.call(btn,x,y,mods)
    end
end

Shoes.app height: 650 do 
  stack do
    tagline "Clicks for non-native widgets"
    flow do
      @ck1 = check checked: true; para "Pass clicks?"
    end
    flow do
      @img = image "#{DIR}/static/shoes-icon-walkabout.png", width: 200, height: 200
      @img.click {|btn,x,y,mods|  @eb.append "Image clicked btn: #{btn} at #{x},#{y} with #{mods}\n"}
      @svg = svg "#{DIR}/samples/good/paris.svg", width: 200, height: 200, group: "#diamond_4"
      @svg.click {|btn,x,y,mods|  @eb.append "Svg clicked btn: #{btn} at #{x},#{y} with #{mods}\n"}
      # click only works on TimeSeries plots
      @plt = plot 200, 200, title: "Test plot", chart: "timeseries"
      @plt.click {|btn,x,y,mods|  @eb.append "Plot clicked btn: #{btn} at #{x},#{y} with #{mods}\n"}
      @btn = button "button" do 
        @eb.append "Button clicked\n"
      end
      @tw = test_widget {|btn,x,y,mods| @eb.append "User Widget: #{btn} at #{x},#{y} with #{mods}\n"}
    end
    @eb = edit_box width: 500, height: 200
    # draw a shape 
    stroke blue
     strokewidth 4
     fill black
     oval 540, 590, 50
  end

  event do |evt| 
    # do not trigger new events here unless you can handle them
    case evt.type
    when :click 
      $stderr.puts "click handler called: #{evt.type} #{evt.button}, #{evt.x} #{evt.y} #{evt.modifiers}"
      if evt.object 
        # Note: for Textblocks the evt.obj is the String of the text block
        $stderr.puts "  non-native widget: #{evt.object.class} width #{evt.width} height #{evt.height}"
      end
      evt.accept = @ck1.checked?
    when :btn_activate
      $stderr.puts "button #{evt.object} at #{evt.type} #{evt.button} #{evt.x} #{evt.y} #{evt.width} #{evt.height}"
      evt.accept = @ck1.checked?
    else
      evt.accept = false
    end
  end

end
