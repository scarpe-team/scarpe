class Scarpe
  module Border
    # Considering a signature like this:
    # border "#00D0FF", :strokewidth => 3, :curve => 12
    def border(color, options = {})
      @border = color
      @options = options
    end

    def style
      styles = (super if defined?(super)) || {}
      return styles unless @border

      styles.merge({
        "border-color": @border,
        "border-style": "solid",
        "border-width": "#{@options[:strokewidth] || 1}px",
        "border-radius": "#{@options[:curve] || 0}px",
      })
    end
  end
end
