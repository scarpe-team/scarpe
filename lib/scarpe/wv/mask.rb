# frozen_string_literal: true

module Scarpe::Webview
  class Mask < Slot
    # JavaScript that extracts SVG shapes and text from the mask element,
    # builds an SVG data URI, and applies it as a CSS mask on the parent slot.
    MASK_APPLICATION_JS = <<~'JS'
      (function(){
        var maskEl = document.getElementById('MASK_ID');
        if (!maskEl) return;

        var innerDiv = maskEl.parentElement;
        if (!innerDiv) return;

        var w = innerDiv.offsetWidth || 500;
        var h = innerDiv.offsetHeight || 500;

        var maskContent = '';

        // Extract SVG shapes (star, oval, rect, line, arc, arrow, shape)
        var svgEls = maskEl.querySelectorAll('svg');
        svgEls.forEach(function(svg) {
          var svgDiv = svg.parentElement;
          if (!svgDiv) return;

          // Get the shape's position relative to the parent slot
          var style = svgDiv.currentStyle || window.getComputedStyle(svgDiv);
          var left = parseFloat(style.left) || 0;
          var top = parseFloat(style.top) || 0;

          // Get SVG dimensions
          var svgW = svg.getAttribute('width') || svg.offsetWidth || 0;
          var svgH = svg.getAttribute('height') || svg.offsetHeight || 0;

          // Clone SVG inner content with white fill for mask
          var inner = svg.innerHTML;
          // Replace all fill and stroke colors with white
          inner = inner.replace(/fill:[^;\"']*/g, 'fill:white');
          inner = inner.replace(/stroke:[^;\"']*/g, 'stroke:white');
          inner = inner.replace(/style="[^"]*"/g, function(match) {
            return match.replace(/fill:[^;\"']*/g, 'fill:white')
                        .replace(/stroke:[^;\"']*/g, 'stroke:white');
          });

          maskContent += '<g transform="translate(' + left + ',' + top + ')">' + inner + '</g>';
        });

        // Extract text elements (para, title, subtitle, etc.)
        var textEls = maskEl.querySelectorAll('p, h1, h2, h3, h4, h5, h6, span');
        textEls.forEach(function(textEl) {
          if (textEl.closest('svg')) return;
          if (!textEl.textContent.trim()) return;

          var cs = window.getComputedStyle(textEl);
          var rect = textEl.getBoundingClientRect();
          var parentRect = innerDiv.getBoundingClientRect();
          var x = rect.left - parentRect.left;
          var y = rect.top - parentRect.top + rect.height * 0.78;

          maskContent += '<text x="' + x + '" y="' + y + '" fill="white" ' +
                         'font-size="' + cs.fontSize + '" ' +
                         'font-weight="' + cs.fontWeight + '" ' +
                         'font-family=\'' + cs.fontFamily.replace(/'/g, '') + '\'>' +
                         textEl.textContent + '</text>';
        });

        if (maskContent) {
          var svgMask = '<svg xmlns="http://www.w3.org/2000/svg" width="' + w + '" height="' + h + '">' +
                        maskContent + '</svg>';
          var dataUrl = 'url(\"data:image/svg+xml,' + encodeURIComponent(svgMask) + '\")';

          // Apply mask to the parent inner div — clips all sibling content
          innerDiv.style.webkitMaskImage = dataUrl;
          innerDiv.style.maskImage = dataUrl;
          innerDiv.style.webkitMaskSize = w + 'px ' + h + 'px';
          innerDiv.style.maskSize = w + 'px ' + h + 'px';
          innerDiv.style.webkitMaskRepeat = 'no-repeat';
          innerDiv.style.maskRepeat = 'no-repeat';
        }

        // Hide the mask source element
        maskEl.style.display = 'none';
      })()
    JS

    def initialize(properties)
      super
    end

    def element(&block)
      props = shoes_styles.merge("html_attributes" => html_attributes)
      render("mask", props, &block)
    end

    # Override to_html to include the mask application trigger.
    # Uses an <img onerror> trick: the broken image fires onerror immediately
    # when inserted into the DOM, even via innerHTML replacement.
    # This ensures the mask JS runs after every DOM update (initial render,
    # needs_update!, full_window_redraw!).
    def to_html
      @children ||= []
      child_markup = @children.map(&:to_html).join
      mask_html = element { child_markup }
      mask_html + mask_trigger_element
    end

    private

    def mask_trigger_element
      js = MASK_APPLICATION_JS.gsub('MASK_ID', html_id)
      # Escape for HTML attribute context
      escaped_js = js.gsub("&", "&amp;").gsub('"', "&quot;")
      %(<img src="data:image/gif;base64,R0lGODlhAQABAIAAAP" ) +
        %(onerror="#{escaped_js}" ) +
        %(style="display:none;width:0;height:0;position:absolute" ) +
        %(data-scarpe-mask-trigger="#{html_id}">)
    end
  end
end
