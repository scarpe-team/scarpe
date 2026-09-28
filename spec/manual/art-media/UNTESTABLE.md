# Entries with no case

Manual entries in the art, background, border, shape, colors, image and video groups that get no `.sspec`, one line each.

## Image internals the display never shows

- `image.memory_cache`: loading one file once is an implementation detail with no observable behaviour; many images from one file look the same either way.
- `image.disk_cache`: the on-disk web cache, its modification times and its ETags are invisible to an app and would need an outside server to probe.
- `image.background_loading`: "does not block Ruby" is a timing claim; the spec has no clock to assert it with and must not sleep.

## Video (ledger L4: out of scope)

The manual ties Video to VideoLAN and ffmpeg and to optional `novideo` builds (manual 3435-3448). Ledger row L4 rules it **OOS**: the native backend draws a placeholder box and Lacci's `Shoes::Video` has only a `url` style. If L4 ever moves Video into scope, `video.hide`, `video.show`, `video.toggle` and `video.move` can be written against the placeholder box first.

- `video.formats`: which codecs load depends on VLC and ffmpeg, which the native backend does not embed (L4).
- `video.optional_support`: about Shoes 3 build flavours (`novideo`), not app behaviour.
- `video.hide`: needs a playing video to show that playback continues (L4).
- `video.length`: needs a decoder to know a length (L4).
- `video.move`: Video is out of scope (L4).
- `video.pause`: needs playback (L4).
- `video.playing?`: needs playback (L4).
- `video.play`: needs playback (L4).
- `video.position`: needs playback (L4).
- `video.position=`: needs playback (L4).
- `video.remove`: "stops it as well" needs playback (L4).
- `video.show`: Video is out of scope (L4).
- `video.stop`: needs playback (L4).
- `video.time`: needs playback (L4).
- `video.time=`: needs playback (L4).
- `video.toggle`: Video is out of scope (L4).
