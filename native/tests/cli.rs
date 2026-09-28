//! The command line the shim starts scarpe-native with.

use std::process::{Command, Output, Stdio};

fn scarpe_native(args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_scarpe-native")).args(args).stdin(Stdio::null()).output().expect("scarpe-native runs")
}

/// The shim passes --ghost for SCARPE_NATIVE_GHOST=1 (DESIGN 12). Headless there is no window to
/// make a ghost of, so this only checks the flag is known; test/native/ghost_test.rb opens ghosts.
#[test]
fn ghost_is_a_flag() {
    let run = scarpe_native(&["--headless", "--ghost"]);
    assert!(run.status.success(), "{}", String::from_utf8_lossy(&run.stderr));
    let help = scarpe_native(&["--headless", "--help"]);
    assert!(String::from_utf8_lossy(&help.stdout).contains("[--ghost]"));
}
