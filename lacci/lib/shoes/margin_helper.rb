module MarginHelper

    def margin_parse(kwargs)

        if kwargs[:margin]
          if kwargs[:margin].is_a?(Numeric)
            if !kwargs[:margin_left]
                kwargs[:margin_left] = kwargs[:margin]
            end
            if !kwargs[:margin_top]
                kwargs[:margin_top] = kwargs[:margin]
            end
            if !kwargs[:margin_right]
                kwargs[:margin_right] = kwargs[:margin]
            end
            if !kwargs[:margin_bottom]
                kwargs[:margin_bottom] = kwargs[:margin]
            end
          else
            margin_props = kwargs[:margin].is_a?(String) ? kwargs[:margin].split(/\s+|\,|-/) : kwargs[:margin]
            if margin_props.length == 1
    
              if !kwargs[:margin_left]
                kwargs[:margin_left] = margin_props[0]
              end
              if !kwargs[:margin_top]
                kwargs[:margin_top] = margin_props[0]
              end
              if !kwargs[:margin_right]
                kwargs[:margin_right] = margin_props[0]
              end
              if !kwargs[:margin_bottom]
                kwargs[:margin_bottom] = margin_props[0]
              end
              
            elsif margin_props.length == 2
    
              if !kwargs[:margin_top]
                kwargs[:margin_top] = margin_props[0]
              end
              if !kwargs[:margin_bottom]
                kwargs[:margin_bottom] = margin_props[1]
              end
              if !kwargs[:margin_left]
                kwargs[:margin_left] = margin_props[0]
              end
              if !kwargs[:margin_right]
                kwargs[:margin_right] = margin_props[1]
              end
    
            elsif margin_props.length == 3
    
              if !kwargs[:margin_left]
                kwargs[:margin_left] = margin_props[0]
              end
              if !kwargs[:margin_top]
                kwargs[:margin_top] = margin_props[2]
              end
              if !kwargs[:margin_right]
                kwargs[:margin_right] = margin_props[1]
              end
              if !kwargs[:margin_bottom]
                kwargs[:margin_bottom] = margin_props[1]
              end
            
            else
    
              if !kwargs[:margin_top]
                kwargs[:margin_top] = margin_props[1]
              end
              if !kwargs[:margin_bottom]
                kwargs[:margin_bottom] = margin_props[3]
              end
              if !kwargs[:margin_left]
                kwargs[:margin_left] = margin_props[0]
              end
              if !kwargs[:margin_right]
                kwargs[:margin_right] = margin_props[2]
              end
    
            end
          end
            
            kwargs[:margin] = nil
        end
        kwargs
    end
        
end