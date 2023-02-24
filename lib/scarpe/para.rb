# frozen_string_literal: true

class Scarpe
  class Para < Scarpe::Widget
    class << self
      def inherited(subclass)
        Scarpe::Widget.widget_classes ||= []
        Scarpe::Widget.widget_classes << subclass
        super
      end
    end

    display_properties :text_items, :stroke, :size, :html_attributes

    def initialize(*args, stroke: nil, size: :para, **html_attributes)
      @text_children = args || []
      # Text_children alternates strings and TextWidgets, so we can't just pass
      # it as a display property. It won't serialize.
      @text_items = text_children_to_items(@text_children)

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
  end

  class Widget
    def banner(*args, **kwargs)
      para(*args, **{ size: :banner }.merge(kwargs))
    end

    def title(*args, **kwargs)
      para(*args, **{ size: :title }.merge(kwargs))
    end

    def subtitle(*args, **kwargs)
      para(*args, **{ size: :subtitle }.merge(kwargs))
    end

    def tagline(*args, **kwargs)
      para(*args, **{ size: :tagline }.merge(kwargs))
    end

    def caption(*args, **kwargs)
      para(*args, **{ size: :caption }.merge(kwargs))
    end

    def inscription(*args, **kwargs)
      para(*args, **{ size: :inscription }.merge(kwargs))
    end

    alias_method :ins, :inscription
  end
end
