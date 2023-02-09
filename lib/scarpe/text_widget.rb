# Scarpe::TextWidget

class Scarpe
  class TextWidget < Scarpe::Widget
    def self.inherited(subclass)
      Scarpe::Widget.widget_classes ||= []
      Scarpe::Widget.widget_classes << subclass
    end
  end
end
