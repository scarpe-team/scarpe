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
      if items
        html_element.inner_html = to_html
        return
      end

      # Not deleting, so this will re-render
      if changes["size"] && SIZES[@size.to_sym]
        @size = @size.to_sym
      end

      super
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
