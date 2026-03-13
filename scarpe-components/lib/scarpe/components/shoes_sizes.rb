# frozen_string_literal: true

module Scarpe
  module Components
    # Canonical mapping of Shoes text size names to pixel values.
    # All display services and components should reference this
    # single source of truth rather than maintaining their own copies.
    #
    # See: https://github.com/scarpe-team/scarpe/issues/505
    module ShoesSizes
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

      # Convert a Shoes size value (symbol, string, or numeric) to a numeric pixel size.
      #
      # @param sz [Symbol, String, Numeric] the size value
      # @return [Integer, nil] the pixel size, or nil if not recognized
      def self.text_size(sz)
        case sz
        when Numeric
          sz
        when Symbol
          SIZES[sz]
        when String
          SIZES[sz.to_sym] || sz.to_i
        else
          raise "Unexpected text size object: #{sz.inspect}"
        end
      end
    end
  end
end
