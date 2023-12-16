# frozen_string_literal: true

class Shoes
  # TextDrawable is the parent class of various classes of
  # text that can go inside a para. This includes normal
  # text, but also links, italic text, bold text, etc.
  #
  # In Shoes3 this corresponds to cText, and it would
  # have methods app, contents, children, parent,
  # style, to_s, text, text= and replace.
  #
  # We don't currently allow things like em("oh", strong("hi!")),
  # so we'll need a rework to match the old interface at
  # some point.
  class TextDrawable < Shoes::Drawable
    class << self
      # rubocop:disable Lint/MissingSuper
      def inherited(subclass)
        Shoes::Drawable.drawable_classes ||= []
        Shoes::Drawable.drawable_classes << subclass

        Shoes::Drawable.drawable_default_styles ||= {}
        Shoes::Drawable.drawable_default_styles[subclass] = {}
      end
      # rubocop:enable Lint/MissingSuper
    end

    shoes_events # No TextDrawable-specific events yet
  end

  class << self
    def default_text_drawable_with(element)
      class_name = element.capitalize

      drawable_class = Class.new(Shoes::TextDrawable) do
        shoes_style :content
        shoes_events # No specific events

        init_args # We're going to pass an empty array to super
        def initialize(content)
          super()

          @content = content

          create_display_drawable
        end

        def text
          self.content
        end

        def to_s
          self.content
        end

        def text=(new_text)
          self.content = new_text
        end
      end
      Shoes.const_set class_name, drawable_class
    end
  end
end

# Shoes3 subclasses of cText were: code, del, em, ins, span, strong, sup, sub

Shoes.default_text_drawable_with(:code)
Shoes.default_text_drawable_with(:em)
Shoes.default_text_drawable_with(:strong)
