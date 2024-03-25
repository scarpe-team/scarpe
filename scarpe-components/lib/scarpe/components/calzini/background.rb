module Scarpe::Components::Calzini
    def background_element(props)
      HTML.render do |h|
        h.div(id: html_id, style: background_style(props))
      end
    end
  
    private
  
    def background_style(props)
      styles = { 
        height: :inherit,
        width: :inherit,
        position: :absolute,
        top: 0,
        left: 0,
        'z-index': -99,
        'box-sizing': 'border-box',
      }

      styles = drawable_style(props).merge(styles)

      bc = props["fill"]
      return styles unless bc

      variable_styles = case bc
      when Array
        {
          background: "rgba(#{bc.join(", ")})",
          'border-color': "rgba(#{bc.join(", ")})",
          'border-width': '1px',
          'border-radius': "#{props['curve']}px",
        }
      when Range
        {
          background: "linear-gradient(45deg, #{bc.first}, #{bc.last})",
          'border-color': "linear-gradient(45deg, #{bc.first}, #{bc.last})",
          'border-width': '1px',
          'border-radius': "#{props['curve']}px",
        }
      when ->(value) { File.exist?(value) }
        {
          background: "url(data:image/png;base64,#{encode_file_to_base64(bc)})"
        }
      else
        {
          background: bc,
          'border-color': bc,
          'border-width': '1px',
          'border-radius': "#{props['curve']}px",
        }
      end

      # binding.irb

      styles.merge(variable_styles)
    end
  end