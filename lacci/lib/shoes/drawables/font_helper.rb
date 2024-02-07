module Font_helper

    def self.parse_font(font)
        
        input = font
        regex = /\s+(?=(?:[^']*'[^']*')*[^']*$)(?![^']*,[^']*')/
        result = input.split(regex)
       
        fs = nil
        fv = nil
        fw = nil
        fss = nil
        ff = ""
        
        fos = ["italic", "oblique"]
        fov = ["small-caps", "initial", "inherit"]
        fow = ["bold", "bolder", "lighter", "100", "200", "300", "400", "500", "600", "700", "800", "900"]
        foss = ["xx-small", "x-small", "small","large", "x-large", "xx-large", "smaller", "larger"]
        
        result.each do |i|
          if fos.include?(i)
            fs = i
            next
          elsif fov.include?(i)
            fv = i
            next
          elsif fow.include?(i)
            fw = i
            next
          elsif foss.include?(i)
            fss = i
            next
          else
            if contains_number?(i)
              
              fss=i;
    
            elsif i != "normal" && i != "medium" && i.strip != ""
    
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

    def self.contains_number?(str)
    
      !!(str =~ /\d/)

    end
end
