# Repro (Night Light): an image drawn larger than its pixels costs four times as much to paint.
#
# A soft round glow, 422 x 422 points in a Retina window, drawn from a PNG. With IMAGE=scaled
# the PNG is 211 x 211 pixels, so it is stretched 4 times to fill 844 x 844 device pixels; with
# IMAGE=native it is 844 x 844, one pixel for each. Both look the same, but with every frame
# painted whole (SCARPE_NATIVE_DAMAGE=off) the scaled one adds about 21 ms to each paint and the
# native one about 4 ms, over the 7 ms the sky's gradient takes (measured 28 Sep 2026 on an M5:
# 27.6 ms against 10.8 ms a paint; ten ovals of the same glow add about 12 ms). The stretched picture seems to be resampled on every paint rather than once. Night
# Light wanted its moon's halo as one smooth picture and went back to ovals.
#
#   IMAGE=scaled SCARPE_NATIVE_DAMAGE=off SCARPE_NATIVE_GHOST=1 SCARPE_NATIVE_STATS=stats \
#     SCARPE_NATIVE_ARGS="--exit-after 5" bundle exec ruby exe/scarpe --native \
#     examples/native/kids/_repros/night_light_3.rb
#   then compare the "paint" column of stats/rust.json's frames with IMAGE=native
#
# expected: the two cost about the same once the stretched copy is made
# actual:   scaled costs about five times what native does, every frame
require "tmpdir"
require "zlib"

# A PNG of a soft glow, `size` pixels square: a signature, a header, the rows squeezed with zlib, an end.
def glow_png(size)
  rows = Array.new(size) do |y|
    pixels = Array.new(size) do |x|
      d = Math.hypot(x + 0.5 - size / 2.0, y + 0.5 - size / 2.0) / (size / 2.0)
      [255, 232, 170, d >= 1 ? 0 : (0.45 * (1 - d)**1.6 * 255).round]
    end
    [0, *pixels.flatten].pack("C*")
  end
  chunk = ->(type, data) { [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N") }
  path = File.join(Dir.mktmpdir("glow"), "glow.png")
  File.binwrite(path, "\x89PNG\r\n\x1a\n".b + chunk.("IHDR", [size, size, 8, 6, 0, 0, 0].pack("NNCCCCC")) +
    chunk.("IDAT", Zlib::Deflate.deflate(rows.join)) + chunk.("IEND", ""))
  path
end

PICTURE = glow_png(ENV.fetch("IMAGE", "scaled") == "native" ? 844 : 211)

Shoes.app(title: "Repro: a stretched picture", width: 960, height: 640) do
  background "#141a44".."#46397f"
  image PICTURE, left: 269, top: 109, width: 422, height: 422
  nostroke
  dot = oval 40, 40, 6, center: true, fill: white
  animate(30) { |frame| dot.style(left: 40 + frame % 20) } # something changes, so each frame is painted
end
