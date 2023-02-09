class Scarpe
  module Spacing
    DIRECTIONS = [:left, :right, :top, :bottom]

    def style
      styles = (super if defined?(super)) || {}

      extract_spacing_styles_for(:margin, styles, @margin)
      extract_spacing_styles_for(:padding, styles, @padding)

      styles
    end

    def extract_spacing_styles_for(attribute, styles, values)
      values ||= spacing_values_from_options(attribute)

      case values
      when Hash
        values.each do |direction, value|
          styles["#{attribute}-#{direction}"] = Dimensions.length(value)
        end
      when Array
        DIRECTIONS.zip(values).to_h.each do |direction, value|
          styles["#{attribute}-#{direction}"] = Dimensions.length(value)
        end
      else
        styles[attribute] = Dimensions.length(values)
      end

      styles.compact!
    end

    def spacing_values_from_options(attribute)
      DIRECTIONS.map do |direction|
        @options.delete("#{attribute}_#{direction}".to_sym)
      end
    end
  end
end
