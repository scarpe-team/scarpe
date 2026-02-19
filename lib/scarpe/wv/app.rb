# frozen_string_literal: true

module Scarpe::Webview
  # Scarpe::Webview::App must only be used from the main thread, due to GTK+ limitations.
  class App < Drawable # App inherits from Drawable to set up linkable IDs and event methods
    attr_reader :control_interface

    attr_writer :shoes_linkable_id

    def initialize(properties)
      super

      # Scarpe's ControlInterface sets up event handlers
      # for the display service that aren't sent to
      # Lacci (Shoes). In general it's used for setup
      # and additional control or testing, outside the
      # Shoes app. This is how CatsCradle and Shoes-Spec
      # set up testing, for instance.
      @control_interface = ControlInterface.new

      # TODO: rename @view
      @view = Scarpe::Webview::WebWrangler.new title: @title,
        width: @width,
        height: @height,
        resizable: @resizable

      @callbacks = {}

      # The control interface has to exist to get callbacks like "override Scarpe app opts".
      # But the Scarpe App needs those options to be created. So we can't pass these to
      # ControlInterface.new.
      @control_interface.set_system_components app: self, doc_root: nil, wrangler: @view

      bind_shoes_event(event_name: "init") { init }
      bind_shoes_event(event_name: "run") { run }
      bind_shoes_event(event_name: "destroy") { destroy }
    end

    attr_writer :document_root

    def init
      scarpe_app = self

      @view.init_code("scarpeInit") do
        request_redraw!
      end

      @view.bind("scarpeHandler") do |*args|
        handle_callback(*args)
      end

      @view.bind("scarpeExit") do
        scarpe_app.destroy
      end

      # Global mouse state tracking for App#mouse (self.mouse in Shoes)
      # Tracks [button, x, y] — button is 1 when left mouse is held, 0 otherwise
      @view.bind("scarpeMouseTracker") do |button, x, y|
        Shoes::DisplayService.mouse_state = [button.to_i, x.to_i, y.to_i]
      end

      # Para hit-test reporting: JS sends para_id and character index on mouse events
      @view.bind("scarpeParaHitReport") do |para_id, char_index|
        if char_index.nil? || char_index == ""
          Shoes::DisplayService.para_hit_cache[para_id] = nil
        else
          Shoes::DisplayService.para_hit_cache[para_id] = char_index.to_i
        end
      end

      # Para cursor_top reporting: JS sends para_id and y-coordinate when cursor changes
      @view.bind("scarpeParaCursorTopReport") do |para_id, top_value|
        Shoes::DisplayService.para_cursor_top_cache[para_id] = top_value.to_i
      end

      @view.instance_variable_get(:@webview).init(<<~JS)
        (function() {
          var _scarpeMouseBtn = 0;
          document.addEventListener('mousemove', function(e) {
            scarpeMouseTracker(_scarpeMouseBtn, e.pageX, e.pageY);
            scarpeParaCursor.hitTestAll(e.pageX, e.pageY);
          });
          document.addEventListener('mousedown', function(e) {
            if (e.button === 0) _scarpeMouseBtn = 1;
            scarpeMouseTracker(_scarpeMouseBtn, e.pageX, e.pageY);
            scarpeParaCursor.hitTestAll(e.pageX, e.pageY);
          });
          document.addEventListener('mouseup', function(e) {
            if (e.button === 0) _scarpeMouseBtn = 0;
            scarpeMouseTracker(_scarpeMouseBtn, e.pageX, e.pageY);
          });
        })();

        // Para cursor/selection management module
        var scarpeParaCursor = (function() {
          // Track which paras have cursor mode enabled
          var _cursorParas = {};  // html_id -> { cursor: int, marker: int|null }

          // Walk text nodes in a DOM element and find the node+offset for a character position
          function findCharPosition(element, charIndex) {
            var walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT, null, false);
            var count = 0;
            var node;
            while (node = walker.nextNode()) {
              var len = node.textContent.length;
              if (count + len > charIndex) {
                return { node: node, offset: charIndex - count };
              }
              count += len;
            }
            // Past end of text: return last position
            if (node) {
              return { node: node, offset: node.textContent.length };
            }
            return null;
          }

          // Count total text characters in an element
          function textLength(element) {
            var walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT, null, false);
            var count = 0;
            while (walker.nextNode()) {
              count += walker.currentNode.textContent.length;
            }
            return count;
          }

          // Get the inner content element (might be wrapped in a div for alignment)
          function getContentElement(htmlId) {
            var el = document.getElementById(htmlId);
            if (!el) return null;
            // If para is wrapped in a div (for alignment), get the inner p/span
            var inner = el.querySelector('p, span.para-inner');
            return inner || el;
          }

          function updateCursor(htmlId, cursorPos, markerPos) {
            _cursorParas[htmlId] = { cursor: cursorPos, marker: markerPos };
            renderCursorOverlay(htmlId);
          }

          function removeCursor(htmlId) {
            delete _cursorParas[htmlId];
            // Remove any existing cursor/selection overlays
            var container = document.getElementById(htmlId);
            if (!container) return;
            var caret = container.querySelector('.shoes-caret');
            if (caret) caret.remove();
            var sel = container.querySelectorAll('.shoes-selection-highlight');
            sel.forEach(function(s) { s.remove(); });
          }

          function renderCursorOverlay(htmlId) {
            var container = document.getElementById(htmlId);
            if (!container) return;
            var info = _cursorParas[htmlId];
            if (!info) return;

            var contentEl = getContentElement(htmlId);
            if (!contentEl) return;

            // Remove existing overlays
            var oldCaret = container.querySelector('.shoes-caret');
            if (oldCaret) oldCaret.remove();
            var oldSel = container.querySelectorAll('.shoes-selection-highlight');
            oldSel.forEach(function(s) { s.remove(); });

            // Position the caret
            var pos = findCharPosition(contentEl, info.cursor);
            if (pos) {
              var range = document.createRange();
              range.setStart(pos.node, pos.offset);
              range.collapse(true);
              var rect = range.getBoundingClientRect();
              var containerRect = container.getBoundingClientRect();

              var caret = document.createElement('div');
              caret.className = 'shoes-caret';
              caret.style.position = 'absolute';
              caret.style.left = (rect.left - containerRect.left) + 'px';
              caret.style.top = (rect.top - containerRect.top) + 'px';
              caret.style.width = '1px';
              caret.style.height = rect.height + 'px';
              caret.style.backgroundColor = '#000';
              caret.style.animation = 'shoesBlink 1s step-end infinite';
              caret.style.pointerEvents = 'none';
              caret.style.zIndex = '10';
              container.style.position = container.style.position || 'relative';
              container.appendChild(caret);

              // Report cursor_top to Ruby (htmlId IS the shoes linkable_id)
              try { scarpeParaCursorTopReport(htmlId, Math.round(rect.top)); } catch(e) {}
            }

            // Render selection highlight if marker is set
            if (info.marker !== null && info.marker !== undefined && info.marker !== info.cursor) {
              var start = Math.min(info.cursor, info.marker);
              var end_ = Math.max(info.cursor, info.marker);
              renderSelectionHighlight(container, contentEl, start, end_);
            }
          }

          function renderSelectionHighlight(container, contentEl, start, end_) {
            var startPos = findCharPosition(contentEl, start);
            var endPos = findCharPosition(contentEl, end_);
            if (!startPos || !endPos) return;

            var range = document.createRange();
            range.setStart(startPos.node, startPos.offset);
            range.setEnd(endPos.node, endPos.offset);

            var rects = range.getClientRects();
            var containerRect = container.getBoundingClientRect();

            for (var i = 0; i < rects.length; i++) {
              var r = rects[i];
              var highlight = document.createElement('div');
              highlight.className = 'shoes-selection-highlight';
              highlight.style.position = 'absolute';
              highlight.style.left = (r.left - containerRect.left) + 'px';
              highlight.style.top = (r.top - containerRect.top) + 'px';
              highlight.style.width = r.width + 'px';
              highlight.style.height = r.height + 'px';
              highlight.style.backgroundColor = 'rgba(51, 153, 255, 0.3)';
              highlight.style.pointerEvents = 'none';
              highlight.style.zIndex = '5';
              container.appendChild(highlight);
            }
          }

          // Hit-test all cursor-enabled paras on mouse events
          function hitTestAll(pageX, pageY) {
            for (var htmlId in _cursorParas) {
              var container = document.getElementById(htmlId);
              if (!container) continue;
              var contentEl = getContentElement(htmlId);
              if (!contentEl) continue;

              var rect = container.getBoundingClientRect();
              // Only hit-test if mouse is reasonably near this para
              if (pageX >= rect.left - 10 && pageX <= rect.right + 10 &&
                  pageY >= rect.top - 10 && pageY <= rect.bottom + 10) {
                var charIndex = hitTestPara(contentEl, pageX, pageY);
                try { scarpeParaHitReport(htmlId, charIndex); } catch(e) {}
              }
            }
          }

          function hitTestPara(contentEl, pageX, pageY) {
            // Use caretRangeFromPoint (WebKit/Blink) or caretPositionFromPoint (Firefox)
            var range;
            if (document.caretRangeFromPoint) {
              range = document.caretRangeFromPoint(pageX, pageY);
            } else if (document.caretPositionFromPoint) {
              var pos = document.caretPositionFromPoint(pageX, pageY);
              if (pos) {
                range = document.createRange();
                range.setStart(pos.offsetNode, pos.offset);
                range.collapse(true);
              }
            }

            if (!range) return null;

            // Count character offset from start of contentEl
            var walker = document.createTreeWalker(contentEl, NodeFilter.SHOW_TEXT, null, false);
            var count = 0;
            var node;
            while (node = walker.nextNode()) {
              if (node === range.startContainer) {
                return count + range.startOffset;
              }
              count += node.textContent.length;
            }
            return null;
          }

          return {
            updateCursor: updateCursor,
            removeCursor: removeCursor,
            hitTestAll: hitTestAll,
            findCharPosition: findCharPosition,
            textLength: textLength
          };
        })();
      JS
    end

    def run
      # This is run before the Webview event loop is up and running
      @control_interface.dispatch_event(:init)

      @view.empty_page = empty_page_element

      # This takes control of the main thread and never returns. And it *must* be run from
      # the main thread. And it stops any Ruby background threads.
      # That's totally cool and normal, right?
      @view.run
    end

    def destroy
      if @document_root || @view
        @control_interface.dispatch_event :shutdown
      end
      @document_root = nil
      if @view
        @view.destroy
        @view = nil
      end
    end

    # Handle property changes for the App
    def properties_changed(changes)
      if changes.key?("title")
        title = changes.delete("title")
        @view.set_title(title.to_s)
      end
      
      if changes.key?("opacity")
        opacity = changes.delete("opacity")
        opacity_val = opacity.nil? ? 1.0 : opacity.to_f.clamp(0.0, 1.0)
        @view.eval_js_async("document.body.style.opacity = '#{opacity_val}';")
      end

      if changes.key?("cursor")
        cursor = changes.delete("cursor")
        css_cursor = shoes_cursor_to_css(cursor)
        @view.eval_js_async("document.body.style.cursor = '#{css_cursor}';")
      end
      super
    end
    
    # Map Shoes cursor symbols to CSS cursor values
    SHOES_CURSOR_MAP = {
      arrow_cursor: "default",
      text_cursor: "text",
      watch_cursor: "wait",
      hand_cursor: "pointer",
      crosshair_cursor: "crosshair",
      move_cursor: "move",
      help_cursor: "help",
      not_allowed_cursor: "not-allowed",
      resize_cursor: "nwse-resize",
    }.freeze
    
    def shoes_cursor_to_css(cursor)
      case cursor
      when Symbol
        SHOES_CURSOR_MAP[cursor] || cursor.to_s.tr("_", "-")
      when String
        SHOES_CURSOR_MAP[cursor.to_sym] || cursor
      else
        "default"
      end
    end

    # All JS callbacks to Scarpe drawables are dispatched
    # via this handler
    def handle_callback(name, *args)
      if @callbacks.key?(name)
        @callbacks[name].call(*args)
      else
        raise Scarpe::UnknownEventTypeError, "No such Webview callback: #{name.inspect}!"
      end
    end

    # Bind a Scarpe callback name; see handle_callback above.
    # See Scarpe::Drawable for how the naming is set up
    def bind(name, &block)
      @callbacks[name] = block
    end

    # Request a full redraw if Webview is running. Otherwise
    # this is a no-op.
    #
    # @return [void]
    def request_redraw!
      wrangler = DisplayService.instance.wrangler
      if wrangler.is_running
        wrangler.replace(@document_root.to_html)
      end
      nil
    end
  end
end
