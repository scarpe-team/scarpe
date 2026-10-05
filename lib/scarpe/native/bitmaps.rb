# frozen_string_literal: true

module Scarpe::Native
  class BitmapError < Scarpe::Error; end

  # Native image sources with explicit lifetimes. These methods belong to DisplayService;
  # the synchronous replies let callers handle rejected uploads before creating drawables.
  module Bitmaps
    MAX_BITMAP_SIDE = 16_384
    MAX_BITMAP_BYTES = 64 * 1024 * 1024
    MAX_BITMAP_KEY_BYTES = 200

    # Upload tightly packed, row-major RGBA8 bytes with straight (not premultiplied) alpha.
    # Returns the key for image(key). Reusing a key replaces its pixels in every window.
    def cache_bitmap(key, width:, height:, pixels:)
      validate_bitmap_key!(key)
      unless [width, height].all? { |side| side.is_a?(Integer) && side.between?(1, MAX_BITMAP_SIDE) }
        raise ArgumentError, "bitmap dimensions must be integers in 1..#{MAX_BITMAP_SIDE}"
      end
      length = width * height * 4
      raise ArgumentError, "bitmap exceeds the 64 MiB upload limit" if length > MAX_BITMAP_BYTES
      unless pixels.is_a?(String) && pixels.bytesize == length
        raise ArgumentError, "bitmap pixels must be a String of exactly width * height * 4 bytes"
      end

      require "base64"
      value = bitmap_request(:cache_bitmap, key: key, width: width, height: height, rgba: Base64.strict_encode64(pixels))
      raise BitmapError, "renderer did not acknowledge bitmap upload" unless value == key

      key
    end

    # Release originals and resized copies. Returns false when the key was already absent.
    # Removing a drawable alone does not release its bitmap.
    def release_bitmap(key)
      validate_bitmap_key!(key)
      value = bitmap_request(:release_bitmap, key: key)
      raise BitmapError, "renderer did not acknowledge bitmap release" unless value == true || value == false

      value
    end

    # Intrinsic dimensions for Image#size/full_width/full_height; nil for an absent key.
    def bitmap_size(key)
      validate_bitmap_key!(key)
      value = bitmap_request(:bitmap_size, key: key)
      return value if value.nil? || (value.is_a?(Array) && value.size == 2 && value.all? { |side| side.is_a?(Integer) && side.between?(1, MAX_BITMAP_SIDE) })

      raise BitmapError, "renderer returned invalid bitmap dimensions"
    end

    private

    def validate_bitmap_key!(key)
      return if key.is_a?(String) && key.ascii_only? && key.bytesize <= MAX_BITMAP_KEY_BYTES && key.match?(/\Amemory:[a-zA-Z0-9._:-]+\z/)

      raise ArgumentError, "bitmap key must be memory: followed by ASCII letters, digits, '.', '_', ':', or '-', at most 200 bytes total"
    end

    def bitmap_request(op, **fields)
      reply = child.request(op, **fields)
      raise BitmapError, reply["error"] if reply["error"]

      reply["value"]
    end
  end
end
