module Scarpe::Components::Calzini
  def border_element(props)
    HTML.render do |h|
      h.div(id: html_id, style: style(props))
    end
  end

  private

  def style(props)
    styles = { 
      height: :inherit,
      width: :inherit,
      position: :absolute, 
      top: 0, 
      left: 0,
      'box-sizing': 'border-box'
    }

    bc = props["stroke"]

    border_style_hash = case bc
    when Range
      { "border-image": "linear-gradient(45deg, #{bc.first}, #{bc.last})" }
    when Array
      { "border-color": "rgba(#{bc.join(", ")})" }
    else
      { "border-color": bc }
    end
    styles = styles.merge(
      "border-style": "solid",
      "border-width": "#{props["strokewidth"]}px",
      "border-radius": "#{props["curve"]}px",
    ).merge(border_style_hash)

    styles.compact
  end
end