Shoes.app :title => "Search sample", :width => 300, :height => 400 do
  msg = "Enter a search."
  stack :margin => 5 do
    @search = edit_line :width => 280

    @search.change do |search|
      if search.text.empty?
        @results.clear{ para msg }
      else
        @results.clear { do_search(search.text) }
      end 
    end

    @results = flow{ para msg }
  end
end

def do_search(word)
  
  data = %w{ place plan plant plot face race rails ruby train trouble double }
  
  data.each do |entry|
    if /#{word}/ =~ entry
      @results.append do 
        stack :margin_top => 5 do 
          background lightyellow, :curve => 6
          para entry
        end
      end
    end         
  end
end
