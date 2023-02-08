#
# From infoq: "Ruby Shoes for lightweight GUIs, graphics and animation"
# http://www.infoq.com/news/2007/09/ruby-shoes
#
Shoes.app do
 radius = 20.0
 vert = width - 30.0
 hor = width - 30.0
 o = oval(hor, vert, 10.0)
 animate(10) do  |anim|
  nofill
  clear do
   oval(hor - radius, vert-radius, radius*2.0)
   satellites = vert /10
   satellites.to_i.times {|x|
    h = hor + Math::sin(((6.28/satellites) * x )) * 40.0
    v = vert - Math::cos(((6.28/satellites) * x ))* 40.0
    fill rgb(1.0/satellites, 1.0/satellites, 0.8)     
    oval(h, v, 5.0)    
   }
   skew vert/10*Math::cos(anim)
  end
 end
 motion do |x,y|
  hor, vert = x, y  
 end
end
