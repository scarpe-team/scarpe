module FontHelper

    def parse_font(font)
        
        # Keep quoted family names together, including commas after the closing quote.
        result = font.scan(/(?:'[^']*'|"[^"]*"|\S)+/)
       
        fs = nil
        fv = nil
        fw = nil
        fss = nil
        ff = ""
        
        fos = ["italic", "oblique"]
        fov = ["small-caps", "initial", "inherit"]
        fow = ["bold", "bolder", "lighter", "100", "200", "300", "400", "500", "600", "700", "800", "900"]
        # Pango weight names accepted by the native renderer, expressed as CSS weights.
        named_weights = {
          "thin" => "100", "hairline" => "100",
          "ultralight" => "200", "extralight" => "200", "light" => "300",
          "regular" => "400", "book" => "400", "medium" => "500",
          "semibold" => "600", "demibold" => "600", "strong" => "700",
          "ultrabold" => "800", "extrabold" => "800", "heavy" => "900", "black" => "900",
        }
        foss = ["xx-small", "x-small", "small","large", "x-large", "xx-large", "smaller", "larger"]
        
        result.each do |i|
          keyword = i.downcase
          if fos.include?(keyword)
            fs = keyword
            next
          elsif fov.include?(keyword)
            fv = keyword
            next
          elsif fow.include?(keyword)
            fw = keyword
            next
          elsif named_weights.key?(keyword) && (keyword != "black" || ff != "")
            # As in the native parser, a leading Black can name a family (Black Chancery).
            fw = named_weights[keyword]
            next
          elsif foss.include?(keyword)
            fss = keyword
            next
          else
            if contains_number?(i) && !i.start_with?("'", '"')
              
              fss=i;
    
            elsif keyword != "normal" && i.strip != ""
    
              if ff == "Arial"
    
                ff = i
    
              else
                
                ff = ff+" "+i
    
              end
            end
          end
          
        end
        
          [fs, fv , fw , fss , ff.strip]
    end

    def contains_number?(str)
    
      !!(str =~ /\d/)

    end
end
