module Scarpe::Components::Calzini
  def border_element(props)
    HTML.render do |h|
      h.div(id: html_id, style: style(props))
    end
  end

  private

  def style(props)
    styles = { 
      border: "#{props['strokewidth']}px solid #{Shoes::Colors.const_get('COLORS').key(props['stroke'][0..-2])}",
      height: :inherit,
      width: :inherit,
      position: :absolute, 
      top: 0, 
      left: 0,
      'box-sizing': 'border-box'
    }

    styles.compact
  end
end