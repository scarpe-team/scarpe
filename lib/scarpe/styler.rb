class Scarpe
  class Styler
    FONT_SIZES = {
      inscription: 10,
      ins: 10,
      para: 12,
      caption: 14,
      tagline: 18,
      subtitle: 26,
      title: 34,
      banner: 48,
    }.freeze

    def initialize(styles)
      @raw = styles
    end

    def style(new = {})
      if new.any?
        @raw = @raw.merge(new)
        @styles = nil
      end

      styles
    end

    private

    def styles
      @styles = @raw.map do |style, value|
        send(style, value)
      end.inject(:merge)
    end

    def stroke(value)
      { "color" => value }
    end

    def font_size(value)
      font_size = value.is_a?(Symbol) ? FONT_SIZES[value] : value

      { "font-size" => Dimensions.length(font_size) }
    end
    alias_method :size, :font_size
  end
end
