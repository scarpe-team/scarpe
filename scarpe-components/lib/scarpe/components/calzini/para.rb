# frozen_string_literal: true

module Scarpe::Components::Calzini
  def para_element(props, &block)
    # Align requires an extra wrapping div.

    # Stacking strikethrough with underline requires multiple elements.
    # We handle this by making strikethrough part of the main element,
    # but using an extra wrapping element for underline.

    tag = props["tag"] || "p"

    para_styles, extra_styles = para_style(props)

    HTML.render do |h|
      if extra_styles.empty?
        h.send(tag, id: html_id, style: para_styles, &block)
      else
        h.div(id: html_id, style: extra_styles.merge(width: "100%")) do
          h.send(tag, style: para_styles, &block)
        end
      end
    end
  end

  private

  def para_style(props)
  
    ds = drawable_style(props)
    s1, s2 = text_specific_styles(props)
    [ds.merge(s1), s2]
  end

  def text_specific_styles(props)
    # Shoes3 allows align: right on TextDrawables like em(), but it does
    # nothing. We can ignore it or (maybe in future?) warn if we see it.

    strikethrough = props["strikethrough"]
    strikethrough = nil if strikethrough == "" || strikethrough == "none"
    s1 = {
      "font": props["font"],
      "font-variant": props["font_variant"],
      "color": rgb_to_hex(props["stroke"]),
      "background-color": rgb_to_hex(props["fill"]),
      "font-size": para_font_size(props),
      "font-family": props["family"],
      "text-decoration-line": strikethrough ? "line-through" : nil,
      "text-decoration-color": props["strikecolor"] ? rgb_to_hex(props["strikecolor"]) : nil,
      "font-weight": props["font_weight"]? props["font_weight"] : nil,
      :'font-style' => case props["emphasis"]
            when "normal"
                "normal"
            when "oblique"
                "oblique"
            when "italic"
                "italic"
            else
                nil
            end,
      :'letter-spacing' => props["kerning"] ? "#{props["kerning"]}px" : nil,
      :'vertical-align' => props["rise"] ? "#{props["rise"]}px" : nil
    }.compact

    s2 = {}
    if props["align"] && props["align"] != ""
      s2[:"text-align"] = props["align"]
    end

    unless [nil, "none"].include?(props["underline"])
      undercolor = rgb_to_hex props["undercolor"]
      s2["text-decoration-color"] = undercolor if undercolor
    end

    # [nil, "none", "single", "double", "low", "error"]
    case props["underline"]
    when nil, "none"
      # Do nothing
    when "single"
      s2["text-decoration-line"] = "underline"
    when "double"
      s2["text-decoration-line"] = "underline"
      s2["text-decoration-style"] = "double"
    when "error"
      s2["text-decoration-line"] = "underline"
      s2["text-decoration-style"] = "wavy"
    when "low"
      s2["text-decoration-line"] = "underline"
      s2["text-underline-offset"] = "0.3rem"
    else
      # This should normally be unreachable
      raise Shoes::Errors::InvalidAttributeValueError, "Unexpected underline type #{props["underline"].inspect}!"
    end

    [s1, s2]
  end

  def para_font_size(props)
    return nil unless props["size"]

    sz = props["size"].to_s
    font_size = SIZES[sz.to_sym] || sz.to_i

    dimensions_length(font_size)
  end

  public

  # The text element is used to render the equivalent of Shoes cText,
  # which includes em, strong, span, link and so on. We use a
  # "content" tag for it which alternates plaintext with a hash of
  # properties.
  def text_drawable_element(prop_array)
    out = String.new # Need unfrozen string

    # Each item should be a String or a property Hash
    # :items, :html_id, :tag, :props
    prop_array.each do |item|
      if item.is_a?(String)
        out << item.gsub("\n", "<br/>")
      else
        s, extra = text_drawable_style(item[:props])
        out << HTML.render do |h|
          if extra.empty?
            h.send(
              item[:tag] || "span",
              class: "id_#{item[:html_id]}",
              style: s,
              **text_drawable_attrs(item[:props])
            ) do
              text_drawable_element(item[:items])
            end
          else
            h.span(class: "id_#{item[:html_id]}", style: extra) do
              h.send(
                item[:tag] || "span",
                class: "id_#{item[:html_id]}",
                style: s,
                **text_drawable_attrs(item[:props])
              ) do
                text_drawable_element(item[:items])
              end
            end
          end
        end
      end
    end

    out
  end

  private

  def text_drawable_attrs(props)
    {
      # These properties will normally only be set by link()
      href: props["click"],
      onclick: props["has_block"] ? handler_js_code("click") : nil,
    }.compact
  end

  def text_drawable_style(props)
    s, extra_s = text_specific_styles(props)

    # Add hover styles, perhaps with CSS pseudo-class

    [drawable_style(props).merge(s), extra_s]
  end
end
