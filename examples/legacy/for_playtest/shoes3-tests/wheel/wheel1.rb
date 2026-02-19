# CHECKED BY SCHWAD

Shoes.app do
  stack height: 200 do
    click do |b,l,t|
     @p.replace "Stack clicked"
    end
    @p = para "None"
    flow width: 200 do
      border red, strokewidth: 2
      para "Flow 1"
      wheel do |d,l,t|
       @p.replace  "Flow 1 wheel #{d}"
      end
    end
    flow width: 200 do
      border black, strokewidth: 4
      para "Flow 2"
      click do |b,l,t|
       @p.replace "Flow 2 clicked"
      end
    end
  end
  stack height: 200 do
    border blue, strokewidth: 2
    para "Stack 2"
  end
  wheel {|d,l,t,mods | @p.replace "default slot wheel #{d} #{mods}"}
end
