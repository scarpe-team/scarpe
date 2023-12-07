# frozen_string_literal: true

# In Italian, tiranti are bootstraps -- the literal pull-on-a-boot kind, not a step to something better.
# Tiranti.rb builds on calzini.rb, but renders a Bootstrap-decorated version of the HTML output.
# You would ordinarily set either Calzini or Tiranti as the top-level HTML renderer, not both.
# You'll include both if you use Tiranti, because it falls back to Calzini for a lot of its rendering.

require "scarpe/components/calzini"

# The Tiranti module expects to be included by a class defining
# the following methods:
#
#     * html_id - the HTML ID for the specific rendered DOM object
#     * handler_js_code(event_name) - the JS handler code for this DOM object and event name
#     * (optional) display_properties - the display properties for this object, unless overridden in render()
module Scarpe::Components::Tiranti
  include Scarpe::Components::Calzini
  extend self

  # Currently we're using Bootswatch 5
  BOOTSWATCH_THEMES = [
    "cerulean",
    "cosmo",
    "cyborg",
    "darkly",
    "flatly",
    "journal",
    "litera",
    "lumen",
    "lux",
    "materia",
    "minty",
    "morph",
    "pulse",
    "quartz",
    "sandstone",
    "simplex",
    "sketchy",
    "slate",
    "solar",
    "spacelab",
    "superhero",
    "united",
    "vapor",
    "yeti",
    "zephyr",
  ]

  BOOTSWATCH_THEME = ENV["SCARPE_BOOTSTRAP_THEME"] || "sketchy"

  def empty_page_element
    <<~HTML
      <html>
        <head id='head-wvroot'>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
          <link rel="stylesheet" href="https://bootswatch.com/5/#{BOOTSWATCH_THEME}/bootstrap.css">
          <link rel="stylesheet" href="https://bootswatch.com/_vendor/bootstrap-icons/font/bootstrap-icons.min.css">
          <style id='style-wvroot'>
            /** Style resets **/
            body {
              height: 100%;
              overflow: hidden;
            }
          </style>
        </head>
        <body id='body-wvroot'>
          <div id='wrapper-wvroot'></div>

          <script src="https://bootswatch.com/_vendor/bootstrap/dist/js/bootstrap.bundle.min.js"></script>
        </body>
      </html>
    HTML
  end

  # def render_stack
  # end
  # def render_flow
  # end

  # How do we want to handle theme-specific colours and primary/secondary buttons in Bootstrap?
  # "Disabled" could be checked in properties. Is there any way we can/should use "outline" buttons?
  def button_element(props)
    HTML.render do |h|
      h.button(id: html_id, type: "button", class: "btn btn-primary", onclick: handler_js_code("click"), style: button_style(props)) do
        props["text"]
      end
    end
  end

  private

  def button_style(props)
    styles = drawable_style(props)

    styles[:"background-color"] = props["color"] if props["color"]
    styles[:"padding-top"] = props["padding_top"] if props["padding_top"]
    styles[:"padding-bottom"] = props["padding_bottom"] if props["padding_bottom"]
    styles[:color] = props["text_color"] if props["text_color"]

    # How do we want to handle font size?
    styles[:"font-size"] = props["font_size"] if props["font_size"]
    styles[:"font-size"] = dimensions_length(text_size(props["size"])) if props["size"]

    styles[:"font-family"] = props["font"] if props["font"]

    styles
  end

  public

  def alert_element(props)
    onclick = handler_js_code(props["event_name"] || "click")

    HTML.render do |h|
      h.div(id: html_id, class: "modal", tabindex: -1, role: "dialog", style: alert_overlay_style(props)) do
        h.div(class: "modal-dialog", role: "document") do
          h.div(class: "modal-content", style: alert_modal_style) do
            h.div(class: "modal-header") do
              h.h5(class: "modal-title") { "Alert" }
              h.button(type: "button", class: "close", data_dismiss: "modal", aria_label: "Close") do
                h.span(aria_hidden: "true") { "&times;" }
              end
            end
            h.div(class: "modal-body") do
              h.p { props["text"] }
            end
            h.div(class: "modal-footer") do
              h.button(type: "button", onclick:, class: "btn btn-primary") { "OK" }
              #h.button(type: "button", class: "btn btn-secondary") { "Close" }
            end
          end
        end
      end
    end
  end

  def check_element(props)
    HTML.render do |h|
      h.div class: "form-check" do
        h.input type: :checkbox,
          id: html_id,
          class: "form-check-input",
          onclick: handler_js_code("click"),
          value: props["text"],
          checked: props["checked"],
          style: drawable_style(props)
      end
    end
  end

  def progress_element(props)
    HTML.render do |h|
      h.div(class: "progress", style: "width: 90%") do
        pct = "%.1f" % ((props["fraction"] || 0.0) * 100.0)
        h.div(
          class: "progress-bar progress-bar-striped progress-bar-animated",
          role: "progressbar",
          "aria-valuenow": pct,
          "aria-valuemin": 0,
          "aria-valuemax": 100,
          style: "width: #{pct}%",
        )
      end
    end
  end

  # para_element is a bit of a hard one, since it does not-entirely-trivial
  # mapping between display objects and IDs. But we don't want Calzini
  # messing with the display service or display objects.
  def para_element(props, &block)
    tag, opts = para_elt_and_opts(props)

    HTML.render do |h|
      h.send(tag, **opts, &block)
    end
  end

  private

  ELT_AND_SIZE = {
    inscription: [:p, 10],
    ins: [:p, 10],
    para: [:p, 12],
    caption: [:p, 14],
    tagline: [:p, 18],
    subtitle: [:h3, 26],
    title: [:h2, 34],
    banner: [:h1, 48],
  }.freeze

  def para_elt_and_opts(props)
    elt, size = para_elt_and_size(props)
    size = dimensions_length(size)

    para_style = drawable_style(props).merge({
      color: rgb_to_hex(props["stroke"]),
      "font-size": para_font_size(props),
      "font-family": props["font"],
    }.compact)

    opts = (props["html_attributes"] || {}).merge(id: html_id, style: para_style)

    [elt, opts]
  end

  def para_elt_and_size(props)
    return [:p, nil] unless props["size"]

    ps = props["size"].to_s.to_sym
    if ELT_AND_SIZE.key?(ps)
      ELT_AND_SIZE[ps]
    else
      sz = props["size"].to_i
      if sz > 18
        [:h2, sz]
      else
        [:p, sz]
      end
    end
  end
end
