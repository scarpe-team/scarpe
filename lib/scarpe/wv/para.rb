# frozen_string_literal: true

module Scarpe::Webview
  class Para < Drawable
    # Currently this is duplicated in Calzini. How to refactor?
    # Similarly, we make some assumptions about when size is a symbol
    # versus string that may not survive JSON deserialization.
    # Do we want to hardcode these sizes in Lacci and have it always
    # pass numbers?
    SIZES = {
      inscription: 10,
      ins: 10,
      para: 12,
      caption: 14,
      tagline: 18,
      subtitle: 26,
      title: 34,
      banner: 48,
    }.freeze
    private_constant :SIZES

    def properties_changed(changes)
      items = changes.delete("text_items")
      text_cursor_changed = changes.delete("text_cursor")
      text_marker_changed = changes.delete("text_marker")

      if items
        html_element.inner_html = to_html
        # If cursor is active, reapply cursor overlay after content change
        update_cursor_display if @text_cursor
        return
      end

      if text_cursor_changed || text_marker_changed
        update_cursor_display
      end

      # Not deleting, so this will re-render
      # Only convert to symbol if size is a String or Symbol (named size like "banner")
      # If it's already an Integer, it's a pixel size and should stay as-is
      if changes["size"] && @size.respond_to?(:to_sym) && SIZES[@size.to_sym]
        @size = @size.to_sym
      end

      super
    end

    # Update the JavaScript-side cursor/selection overlay for this para.
    # This calls into the scarpeParaCursor JS module to position the caret
    # and highlight the selection range.
    def update_cursor_display
      cursor_pos = @text_cursor
      marker_pos = @text_marker

      if cursor_pos.nil?
        # Remove cursor display
        js = "scarpeParaCursor.removeCursor('#{html_id}')"
      else
        # Update cursor and optional selection
        js = "scarpeParaCursor.updateCursor('#{html_id}', #{cursor_pos}, #{marker_pos.nil? ? 'null' : marker_pos})"
      end
      html_element.instance_variable_get(:@webwrangler).dom_change(js)
    end

    def items_to_display_children(items)
      return [] if items.nil?

      items.map do |item|
        if item.is_a?(String)
          item
        else
          Scarpe::Webview::DisplayService.instance.query_display_drawable_for(item)
        end
      end
    end

    def element(&block)
      render("para", &block)
    end

    # Because para's to_html takes a block, and it needs to convert IDs into display
    # drawables, it needs to also override to_html
    def to_html
      @children ||= []

      element { child_markup }
    end

    private

    def child_markup
      # The children should be only text strings or TextDrawables.
      items_to_display_children(@text_items).map do |child|
        if child.respond_to?(:to_html)
          child.to_html
        else
          child.gsub("\n", "<br>")
        end
      end.join
    end
  end
end
