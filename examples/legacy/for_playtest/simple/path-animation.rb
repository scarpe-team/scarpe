Shoes.app(title: "Drag the dot to make a path. Redrag to extend.") do
   RADIUS = 20
   # Use fixed starting position since self.width/height may be nil at init
   @path = [[200, 200, RADIUS]]
   
   @controller = nil
   click do |btn, left, top|
      px, py, pr = @path.last
      puts "CLICK at (#{left}, #{top}) - dot at (#{px}, #{py}) radius=#{pr}"
      puts "  In range X? #{left.between?(px - pr, px + pr)}"
      puts "  In range Y? #{top.between?(py - pr, py + pr)}"
      if left.between?(px - pr, px + pr) and top.between?(py - pr, py + pr)
         @controller = true
         puts "  -> DRAG STARTED!"
      end
   end
   release do |btn, left, top|
      @controller = nil
   end

   motion do |left, top|
      @path << [left, top, RADIUS] unless @controller.nil?
   end
   
   button("reset") do
      @index = 0
      @path = [@path.first]
      @controller = nil
   end
   
   @stack = stack :top => 0, :left => 0

   @index = 0
   animate(24) do
      @stack.clear do
         fill red(0.05)
         stroke red(0.05)
         ovals = @path.collect { |x, y, r| oval x, y, r, :center => true }
         ovals.first.style :fill => fuchsia, :stroke => fuchsia
         ovals.last.style :fill => blue, :stroke => blue
         
         if @controller.nil? and @path.size > 1
            fill green
            stroke green
            rotate -5
            x, y, r = @path[@index]
            rect x, y, r * 4, r * 4, r / 2, :center => true
            @index = (@index < @path.size - 1) ? @index + 1 : 0
         end
      end
   end
end