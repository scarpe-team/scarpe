# frozen_string_literal: true

require "zlib"

module SpecSuite
  # Just enough PNG to answer "is this snapshot blank?": 8-bit, non-interlaced greyscale,
  # RGB, grey+alpha and RGBA, which is what tiny-skia and the png crate write.
  class Png
    class Unsupported < StandardError; end

    SIGNATURE = "\x89PNG\r\n\x1A\n".b
    CHANNELS = { 0 => 1, 2 => 3, 4 => 2, 6 => 4 }.freeze

    attr_reader :width, :height, :channels

    def self.read(path)
      new(File.binread(path))
    end

    def initialize(bytes)
      raise Unsupported, "not a PNG" unless bytes.start_with?(SIGNATURE)

      idat = +"".b
      each_chunk(bytes) do |type, data|
        case type
        when "IHDR" then read_header(data)
        when "IDAT" then idat << data
        end
      end
      @raw = Zlib::Inflate.inflate(idat)
    end

    # "#rrggbbaa" when every pixel is the same colour, else nil. Stops at the first row that differs.
    def flat_color
      first = nil
      each_row do |row|
        first ||= row.byteslice(0, channels)
        return nil unless row == first * width
      end
      "#" + rgba(first.bytes).map { |channel| format("%02x", channel) }.join
    end

    def pixel(x, y)
      each_row.with_index { |row, index| return rgba(row.byteslice(x * channels, channels).bytes) if index == y }
      raise IndexError, "no row #{y}"
    end

    private

    def each_chunk(bytes)
      offset = SIGNATURE.bytesize
      while offset < bytes.bytesize
        length, type = bytes.byteslice(offset, 8).unpack("Na4")
        yield type, bytes.byteslice(offset + 8, length)
        offset += 12 + length
      end
    end

    def read_header(data)
      @width, @height, depth, color_type, _compression, _filter, interlace = data.unpack("NNCCCCC")
      @channels = CHANNELS[color_type]
      raise Unsupported, "colour type #{color_type}" unless @channels
      raise Unsupported, "bit depth #{depth}" unless depth == 8
      raise Unsupported, "interlaced" unless interlace.zero?
    end

    def each_row
      return enum_for(:each_row) unless block_given?

      stride = width * channels
      previous = Array.new(stride, 0)
      height.times do |y|
        line = @raw.byteslice(y * (stride + 1), stride + 1).bytes
        filter = line.shift
        previous = reconstruct(filter, line, previous)
        yield previous.pack("C*")
      end
    end

    def reconstruct(filter, line, above)
      bpp = channels
      out = Array.new(line.size)
      line.each_with_index do |byte, i|
        left = i >= bpp ? out[i - bpp] : 0
        up = above[i]
        up_left = i >= bpp ? above[i - bpp] : 0
        out[i] = (byte + predictor(filter, left, up, up_left)) & 0xFF
      end
      out
    end

    def predictor(filter, left, up, up_left)
      case filter
      when 0 then 0
      when 1 then left
      when 2 then up
      when 3 then (left + up) / 2
      when 4 then paeth(left, up, up_left)
      else raise Unsupported, "filter #{filter}"
      end
    end

    def paeth(left, up, up_left)
      estimate = left + up - up_left
      distances = [(estimate - left).abs, (estimate - up).abs, (estimate - up_left).abs]
      [left, up, up_left][distances.index(distances.min)]
    end

    def rgba(bytes)
      case channels
      when 1 then [bytes[0]] * 3 + [255]
      when 2 then [bytes[0]] * 3 + [bytes[1]]
      when 3 then bytes + [255]
      else bytes
      end
    end
  end
end
