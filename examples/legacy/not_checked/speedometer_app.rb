# Source: https://www.hanselman.com/blog/the-weekly-source-code-29-ruby-and-shoes-and-the-first-ruby-virus

class Speedometer < Shoes::Widget
  attr_accessor :range, :tick, :position
  def initialize opts = {}
    @range = opts[:range] || 200
    @tick = opts[:tick] || 10
    @position = opts[:position] || 0
    @cx, @cy = self.left + 110, self.top + 100
 
    nostroke
    rect :top => self.top, :left => self.left,
      :width => 220, :height => 200
    nofill
    stroke white
    oval :left => @cx - 50, :top => @cy - 50, :radius => 100
    (ticks + 1).times do |i|
      radial_line 225 + ((270.0 / ticks) * i), 70..80
      radial_line 225 + ((270.0 / ticks) * i), 45..49
    end
    strokewidth 2
    oval :left => @cx - 70, :top => @cy - 70, :radius => 140
    stroke lightgreen
    oval :left => @cx - 5, :top => @cy - 5, :radius => 10
    @needle = radial_line 225 + ((270.0 / @range) * @position), 0..90
  end
  def ticks; @range / @tick end
  def radial_line deg, r
    pos = ((deg / 360.0) * (2.0 * Math::PI)) - (Math::PI / 2.0)
    line (Math.cos(pos) * r.begin) + @cx, (Math.sin(pos) * r.begin) + @cy,
      (Math.cos(pos) * r.end) + @cx, (Math.sin(pos) * r.end) + @cy
  end
  def position= pos
    @position = pos
    @needle.remove
    append do
      @needle = radial_line 225 + ((270.0 / @range) * @position), 0..90
    end
  end
end
 
Shoes.app do
  stack do
    para "Enter a number between 0 and 100"
    flow do
      @p = edit_line
      button "OK" do
        @s.position = @p.text.to_i
      end
    end
 
    @s = speedometer :range => 100, :ticks => 10
  end
end

