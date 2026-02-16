Shoes.app do
    def main slot, stuff
        slot.clear do
            stuff.each_with_index do |x, i|
                flow do                             ####### FIX 1 : COMMENT THIS LINE 
                   r =  radio :item, checked: true; para "Radio-#{i}" 
                   r.checked = true if i == 1 
                end                                   ####### FIX 1 : COMMENT THIS LINE 
            end
        end
    end
    stack do    
      ITEMS = Array.new( 3, 1 )
      desktop = stack left: 20, top: 40, width: 200 
      main desktop, ITEMS
      button "Reset" do
          main  desktop, ITEMS
      end
    end
end
