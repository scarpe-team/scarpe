module Scarpe
  class HTML
    TAGS = %i[div p button]

    def self.render(&block)
      new(&block).value
    end

    def initialize(&block)
      @buffer = ""
      @buffer += block.call(self)
    end

    def value
      @buffer
    end

    def respond_to_missing?(name, include_all = false)
      TAGS.include?(name) || super(name, include_all)
    end

    def p(*args, &block)
      method_missing(:p, *args, &block)
    end

    def method_missing(name, *args, &block)
      raise NoMethodError, "no method #{name} for #{self.class.name}" unless TAGS.include?(name)

      buffer = "<#{name} #{render_attributes(*args)}>"
      buffer += if block_given?
                  block.call(self)
                else
                  args.first
                end

      buffer += "</#{name}>"

      buffer
    end

    private

    def render_attributes(attributes = {})
      attributes[:style] = render_style(attributes[:style]) if attributes[:style]

      attributes.map { |k, v| "#{k}=\"#{v}\"" }.join(" ")
    end

    def render_style(style)
      return style unless style.is_a?(Hash)

      style.map { |k, v| "#{k}:#{v}" }.join(";")
    end
  end
end
