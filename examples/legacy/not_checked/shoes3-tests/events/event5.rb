Shoes.app(width: 200, height: 200) do
   @img1 = image "#{DIR}/static/shoes-icon-walkabout.png", left: 0, top: 0, width: 200, height: 200
   @img2 = image "#{DIR}/static/shoes-icon-blue.png", left: 50, top: 50, width: 100, height: 100
   event do |evt|
    case evt.type
    when :click 
      $stderr.puts "click handler called: #{evt.type} #{evt.button}, #{evt.x} #{evt.y} #{evt.modifiers}"
      if evt.object 
        # Note: for Textblocks the evt.obj is the String of the text block
        $stderr.puts "  non-native widget: #{evt.object.class} width #{evt.width} height #{evt.height}"
      end
      evt.accept = true
    else
      evt.accept = false
    end
   end
end
