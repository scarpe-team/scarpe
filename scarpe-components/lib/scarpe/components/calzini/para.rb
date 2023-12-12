# frozen_string_literal: true

module Scarpe::Components::Calzini
  # para_element is a bit of a hard one, since it does not-entirely-trivial
  # mapping between display objects and IDs. But we don't want Calzini
  # messing with the display service or display objects.
  def para_element(props, &block)
    HTML.render do |h|
      if props["align"]
        h.div(id: html_id, style: {"text-align": props["align"], width: "100%"}) do
          h.p(style: para_style(props), &block)
        end
      else
        h.p(id: html_id, style: para_style(props), &block)
      end
    end
  end

  private

  def para_style(props)
    drawable_style(props).merge({
      color: rgb_to_hex(props["stroke"]),
      "font-size": para_font_size(props),
      "font-family": props["font"],
    }.compact)
  end

  def para_font_size(props)
    return nil unless props["size"]

    sz = props["size"].to_s
    font_size = SIZES[sz.to_sym] || sz.to_i

    dimensions_length(font_size)
  end
end
