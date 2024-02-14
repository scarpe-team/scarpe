module MarginHelper

  def margin_parse(kwargs)

      if kwargs[:margin]

        if kwargs[:margin].is_a?(Numeric)

          if !kwargs[:margin_top]
            kwargs[:margin_top] = kwargs[:margin]
          end
          if !kwargs[:margin_bottom]
            kwargs[:margin_bottom] = kwargs[:margin]
          end
          if !kwargs[:margin_left]
            kwargs[:margin_left] = kwargs[:margin]
          end
          if !kwargs[:margin_right]
            kwargs[:margin_right] = kwargs[:margin]
          end

        elsif kwargs[:margin].is_a?(Hash)

          kwargs[:margin].each do |key,value|
            kwargs[:"margin_#{key}"] = value
          end

        else
          margin_props = kwargs[:margin].is_a?(String) ? kwargs[:margin].split(/\s+|\,|-/) : kwargs[:margin]
          if margin_props.length == 1

            if !kwargs[:margin_top]
              kwargs[:margin_top] = margin_props[0]
            end
            if !kwargs[:margin_bottom]
              kwargs[:margin_bottom] = margin_props[0]
            end
            if !kwargs[:margin_left]
              kwargs[:margin_left] = margin_props[0]
            end
            if !kwargs[:margin_right]
              kwargs[:margin_right] = margin_props[0]
            end

          elsif margin_props.length == 2
  
            raise(Shoes::Errors::InvalidAttributeValueError, "Margin don't support 2-3 values as Array/string input for using 2-3 input you can use the hash input method like '{left:value, right:value, top:value, bottom:value}'")
  
          elsif margin_props.length == 3
  
            raise(Shoes::Errors::InvalidAttributeValueError, "Margin don't support 2-3 values as Array/string input for using 2-3 input you can use the hash input method like '{left:value,right:value,top:value,bottom:value}'")
          
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
      if kwargs["options"] && !kwargs[:margin] && !kwargs[:margin_left] && !kwargs[:margin_right] && !kwargs[:margin_top] && !kwargs[:margin_bottom]
        kwargs[options].each do |key,value|
          kwargs[key] = value
        end
      end
      kwargs
  end
end
