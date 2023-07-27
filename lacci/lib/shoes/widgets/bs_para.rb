# frozen_string_literal: true

module Shoes
  class BsPara < Shoes::Widget
    display_properties :text_items, :stroke, :size, :font, :html_attributes, :hidden

    def initialize(*args, stroke: nil, size: 10, font: nil, hidden: false, **html_attributes)
      @text_children = args || []
      if hidden
        @hidden_text_items = text_children_to_items(@text_children)
        @text_items = []
      else
        # Text_children alternates strings and TextWidgets, so we can't just pass
        # it as a display property. It won't serialize.
        @text_items = text_children_to_items(@text_children)
        @hidden_text_items = []
      end
      stroke = to_rgb(stroke)

      @html_attributes = html_attributes || {}

      super

      create_display_widget
    end

    def text_children_to_items(text_children)
      text_children.map { |arg| arg.is_a?(String) ? arg : arg.linkable_id }
    end

    def replace(*children)
      @text_children = children

      # This should signal the display widget to change
      self.text_items = text_children_to_items(@text_children)
    end

    def hide
      # idempotent
      return unless @hidden_text_items.empty?

      @hidden_text_items = self.text_items
      self.text_items = []
    end

    def show
      # idempotent
      return unless self.text_items.empty?

      self.text_items = @hidden_text_items
      @hidden_text_items = []
    end
  end
end

module Shoes
  class Widget
    def bs_banner(*args, **kwargs)
      bs_para(*args, **{ size: :banner }.merge(kwargs))
    end

    def bs_title(*args, **kwargs)
      bs_para(*args, **{ size: :title }.merge(kwargs))
    end

    def bs_subtitle(*args, **kwargs)
      bs_para(*args, **{ size: :subtitle }.merge(kwargs))
    end

    def bs_tagline(*args, **kwargs)
      bs_para(*args, **{ size: :tagline }.merge(kwargs))
    end

    def bs_caption(*args, **kwargs)
      bs_para(*args, **{ size: :caption }.merge(kwargs))
    end

    def bs_inscription(*args, **kwargs)
      bs_para(*args, **{ size: :inscription }.merge(kwargs))
    end

    alias_method :ins, :inscription
  end
end
