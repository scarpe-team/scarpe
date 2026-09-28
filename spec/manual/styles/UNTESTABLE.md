# Styles entries with no case

Every other entry whose id starts with `styles.` has at least one case in this directory.

| Entry | Manual | Why there is no case |
|---|---|---|
| `styles.autoplay` | 1093-1098 | Video is out of scope (ledger L4: the VLC-era player shipped only in some builds, and the native display draws a placeholder). Lacci's `Video` has no `:autoplay` style and no `playing?`, so nothing observable could change. |
