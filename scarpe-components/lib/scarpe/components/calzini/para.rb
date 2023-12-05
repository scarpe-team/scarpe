# frozen_string_literal: true

module Scarpe::Components::Calzini
  # para_element is a bit of a hard one, since it does not-entirely-trivial
  # mapping between display objects and IDs. But we don't want Calzini
  # messing with the display service or display objects.
  def para_element(props, &block)
    HTML.render do |h|
      h.p(**para_options(props), &block)
    end
  end

  private

  def para_options(props)
    (props["html_attributes"] || {}).merge(id: html_id, style: para_style(props))
  end

  def para_style(props)
    drawable_style(props).merge({
      color: rgb_to_hex(props["stroke"]),
      "font-size": para_font_size(props),
      "font-family": props["font"],
      "margin": calculate_margin(props['html_attributes']) 
    }.compact)
  end

  def calculate_margin(props)
    margin = {top: props[:margin_top], right: props[:margin_right], bottom: props[:margin_bottom], left: props[:margin_left]}
    margin = margin.transform_values { |val| (val || 0).to_i }

    case props[:margin]
    when Integer
      margin = margin.transform_values{|val| val + props[:margin]}
    when Array
      new_margin = {top: props[:margin][0].to_i, right: props[:margin][1].to_i, bottom: props[:margin][2].to_i, left: props[:margin][3].to_i}
      margin.merge!(margin, new_margin) { |key, old_value, new_value| old_value + new_value }
    end

    "#{margin[:top]}px #{margin[:right]}px #{margin[:bottom]}px #{margin[:left]}px"
  end

  def para_font_size(props)
    return nil unless props["size"]

    sz = props["size"].to_s
    font_size = SIZES[sz.to_sym] || sz.to_i

    dimensions_length(font_size)
  end
end
