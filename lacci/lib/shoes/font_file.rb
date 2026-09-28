# frozen_string_literal: true

class Shoes
  # Reads the family names out of a TrueType or OpenType font file (a .ttc collection
  # gives every font's), so `font(path)` can return them as the manual says it does
  # (manual 766-767, ledger K4). Anything that is not a readable font has none.
  module FontFile
    extend self

    COLLECTION_TAG = "ttcf"
    FONT_TAGS = ["\x00\x01\x00\x00".b, "OTTO", "true"].freeze
    TYPOGRAPHIC_FAMILY = 16 # preferred over the plain family, as fontdb picks them
    FAMILY = 1

    # @param path [String] a font file
    # @return [Array<String>, nil] its family names, or nil if it holds no fonts
    def families(path)
      data = File.binread(path)
      names = font_offsets(data).flat_map { |offset| family_names(data, offset) }.uniq
      names.empty? ? nil : names
    rescue SystemCallError, NoMethodError, ArgumentError, TypeError, RangeError, EncodingError
      nil
    end

    private

    def font_offsets(data)
      case data[0, 4]
      when COLLECTION_TAG then Array.new(data[8, 4].unpack1("N")) { |i| data[12 + 4 * i, 4].unpack1("N") }
      when *FONT_TAGS then [0]
      else []
      end
    end

    def family_names(data, font_offset)
      name_table = table_offset(data, font_offset, "name") or return []
      _format, count, strings = data[name_table, 6].unpack("n3")
      records = Array.new(count) { |i| data[name_table + 6 + 12 * i, 12].unpack("n6") }

      by_id = records.group_by { |record| record[3] }
      chosen = by_id[TYPOGRAPHIC_FAMILY] || by_id[FAMILY] || []
      chosen.filter_map do |platform, _encoding, _language, _id, length, offset|
        decode(data[name_table + strings + offset, length], platform)
      end.uniq
    end

    def table_offset(data, font_offset, tag)
      tables = data[font_offset + 4, 2].unpack1("n")
      tables.times do |i|
        record = font_offset + 12 + 16 * i
        return data[record + 8, 4].unpack1("N") if data[record, 4] == tag
      end
      nil
    end

    # Windows and Unicode names are UTF-16BE; Mac Roman names are near enough ASCII. The
    # UTF-16 is read by hand: a packaged app's Ruby carries no encoding transcoders
    # (lib/scarpe/package.rb), and there String#encode raised, so font(path) answered nil and
    # the font never reached the display.
    def decode(bytes, platform)
      text = platform == 1 ? mac_roman(bytes) : utf_16be(bytes)
      name = text&.strip
      name.nil? || name.empty? ? nil : name
    end

    def utf_16be(bytes)
      units = bytes.unpack("n*")
      points = []
      while (unit = units.shift)
        points << if unit.between?(0xD800, 0xDBFF) && units.first&.between?(0xDC00, 0xDFFF)
          0x10000 + ((unit - 0xD800) << 10) + (units.shift - 0xDC00)
        elsif unit.between?(0xD800, 0xDFFF)
          0xFFFD # half a pair, alone
        else
          unit
        end
      end
      points.pack("U*")
    end

    # ASCII as it is; anything past it needs Ruby's Mac Roman transcoder, and without one (a
    # packaged app) the name is skipped, since the same font names itself in UTF-16 too.
    def mac_roman(bytes)
      return bytes.dup.force_encoding(Encoding::UTF_8) if bytes.ascii_only?

      bytes.dup.force_encoding(Encoding::MACROMAN).encode(Encoding::UTF_8)
    rescue EncodingError
      nil
    end
  end
end
