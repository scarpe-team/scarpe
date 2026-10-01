# Untestable entries: events and slots

Entries from `native/research/manual_inventory.json` in this group that get no case.

- `events.keypress.reserved_hotkeys`: the manual reserves Alt-Period, Alt-Question and Alt-Slash for Shoes 3's own windows. Since 28 Sep 2026 Alt-Slash opens the Shoes console and never reaches the app (ledger H10, K8; `native/tests/protocol.rs` and `test/native/errors_test.rb` check it); Alt-Period and Alt-Question, Shoes 3's file selector and manual, still reach the app, and H10 leaves them out of scope.
