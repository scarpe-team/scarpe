# frozen_string_literal: true

# In Italian, tiranti are bootstraps -- the literal pull-on-a-boot kind, not a step to something better.
# Tiranti.rb builds on calzini.rb, but renders a Bootstrap-decorated version of the HTML output.
# You can set Tiranti as your HTML renderer and you'll get Bootstrap versions of all the drawables.
# Tiranti requires Calzini's files because it falls back to Calzini for a lot of its rendering.

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

  # Currently we're using Bootswatch 5.
  # Bootswatch themes downloaded from https://bootswatch.com/5/THEME_NAME/bootstrap.css

  def empty_page_element(theme: ENV["SCARPE_BOOTSTRAP_THEME"] || "sketchy")
    comp_dir = File.expand_path("#{__dir__}/../../..")
    bootstrap_js_url = Scarpe::Webview.asset_server.asset_url("#{comp_dir}/assets/bootstrap-themes/bootstrap.bundle.min.js", url_type: :asset)
    theme_url = Scarpe::Webview.asset_server.asset_url("#{comp_dir}/assets/bootstrap-themes/bootstrap-#{theme}.css", url_type: :asset)
    icons_url = Scarpe::Webview.asset_server.asset_url("#{comp_dir}/assets/bootstrap-themes/bootstrap-icons.min.css", url_type: :asset)

    <<~HTML
      <html>
        <head id='head-wvroot'>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
          <link rel="stylesheet" href=#{theme_url.inspect}>
          <link rel="stylesheet" href=#{icons_url.inspect}>
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

          <script src=#{bootstrap_js_url}></script>
        </body>
      </html>
    HTML
  end

  # How do we want to handle theme-specific colours and primary/secondary buttons in Bootstrap?
  # "Disabled" could be checked in properties. Is there any way we can/should use "outline" buttons?
  def button_element(props)
    HTML.render do |h|
      h.button(
        id: html_id,
        type: "button",
        class: props["html_class"] ? "btn #{props["html_class"]}" : "btn btn-primary",
          onclick: handler_js_code("click"), style: button_style(props)
      ) do
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
    progress_style = drawable_style(props).merge({
      width: "90%",
    })
    HTML.render do |h|
      h.div(id: html_id, class: "progress", style: progress_style) do
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

  def para_element(props, &block)
    ps, _extra = para_style(props)
    size = ps[:"font-size"] || "12px"
    size_int = size.to_i # Mostly useful if it's something like "12px"
    if size.include?("calc") || size.end_with?("%")
      # Very big text!
      props["tag"] = "h2"
    elsif size_int >= 48
      props["tag"] = "h1"
    elsif size_int >= 34
      props["tag"] = "h2"
    elsif size_int >= 26
      props["tag"] = "h3"
    else
      props["tag"] = "p"
    end

    super
  end
end
