# A stretched picture (a bench, from the Night Light lane).
#
# A soft round glow, 422 x 422 points in a Retina window, drawn from a PNG. With IMAGE=scaled the
# PNG is 211 px square, stretched to 844 device pixels; with IMAGE=native it is 844 px, one pixel
# for each. The stretched one used to be resampled, bicubic, on every paint. Since 28 Sep 2026
# the image cache keeps a copy at the size it is drawn at (stats: images_resampled).
#
#   IMAGE=scaled SCARPE_NATIVE_DAMAGE=off SCARPE_NATIVE_GHOST=1 SCARPE_NATIVE_STATS=stats \
#     SCARPE_NATIVE_ARGS="--exit-after 5" bundle exec ruby exe/scarpe --native \
#     examples/native/bench/stretched_picture.rb
#   then compare the paint column of stats/rust.json's frames with IMAGE=native
#
# M5, 28 Sep 2026, every frame painted whole at 2x, median paint of about 145 frames: before,
# 15.1 ms stretched against 5.8 ms native; after, 5.8 ms for both, one copy made.
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

Shoes.app(title: "A stretched picture", width: 960, height: 640) do
  background "#141a44".."#46397f"
  image PICTURE, left: 269, top: 109, width: 422, height: 422
  nostroke
  dot = oval 40, 40, 6, center: true, fill: white
  animate(30) { |frame| dot.style(left: 40 + frame % 20) } # something changes, so each frame is painted
end
