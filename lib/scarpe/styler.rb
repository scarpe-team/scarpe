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

    def style
      @style = @raw.map do |style, value|
        send(style, value)
      end.inject(:merge)
    end

    def update_style(**styles)
      @raw.merge!(styles)
      @style = nil
    end

    private

    def styles
    end

    def stroke(value)
      { "color" => value }
    end

    def size(value)
      font_size = value.is_a?(Symbol) ? FONT_SIZES[value] : value

      { "font-size" => Dimensions.length(font_size) }
    end

    def background(value)
      color = if value.is_a?(Range)
          "linear-gradient(45deg, #{value.first}, #{value.last})"
        else
          value
        end

      { background: color }
    end
  end
end
