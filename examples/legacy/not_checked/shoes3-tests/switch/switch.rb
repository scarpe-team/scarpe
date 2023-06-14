Shoes.app width: 300, height: 200 do
   flow do
      switch font: "monospace Italic 10", stroke: red; para
   end
   
   flow do
      @n = switch(active: true) do
         @p.text = (@n.active? ? "true": "false") unless @p.nil?
      end
      @p = para
   end
   
   flow do
      @m = switch width: 80
      @m.click do
        #$stderr.puts "Click"
        @m.active? ? @e.start : @e.stop
      end
      @e = every(1) { |count| @q.text = count unless @q.nil? & @m.active? }
      @q = para ""
   end
   
   start do
      @e.stop
      @p.text = @n.active? ? "true" : "false"
      @m.active = false
   end
end
