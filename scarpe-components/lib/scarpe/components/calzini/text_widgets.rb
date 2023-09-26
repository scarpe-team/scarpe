# frozen_string_literal: true

module Scarpe::Components::Calzini
  def link_element(props)
    HTML.render do |h|
      h.a(**link_attributes(props)) do
        props["text"]
      end
    end
  end

  def span_element(props, &block)
    HTML.render do |h|
      h.span(**span_options(props), &block)
    end
  end

  def code_element(props, &block)
    HTML.render do |h|
      h.code(&block)
    end
  end

  def em_element(props, &block)
    HTML.render do |h|
      h.em(&block)
    end
  end

  def strong_element(props, &block)
    HTML.render do |h|
      h.strong(&block)
    end
  end

  private

  def link_attributes(props)
    {
      id: html_id,
      href: props["click"],
      onclick: (handler_js_code("click") if props["has_block"]),
      style: widget_style(props),
    }.compact
  end

  def span_style(props)
    {
      color: props["stroke"],
      "font-size": span_font_size(props),
      "font-family": props["font"],
    }.compact
  end

  def span_options(props)
    (props["html_attributes"] || {}).merge(id: html_id, style: span_style(props))
  end

  def span_font_size(props)
    sz = props["size"]
    font_size = SIZES.key?(sz.to_s.to_sym) ? SIZES[sz.to_s.to_sym] : sz

    dimensions_length(font_size)
  end
end
