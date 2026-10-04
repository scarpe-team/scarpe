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

// A Windows GUI executable still has to write to the pipes supplied by the Ruby shim.
#[test]
fn output_and_errors_reach_redirected_streams() {
    let version = scarpe_native(&["--version"]);
    assert!(version.status.success());
    assert_eq!(String::from_utf8(version.stdout).unwrap().trim(), concat!("scarpe-native ", env!("CARGO_PKG_VERSION")));
    assert!(version.stderr.is_empty());

    let invalid = scarpe_native(&["--headless", "--unknown-option"]);
    assert_eq!(invalid.status.code(), Some(2));
    assert!(invalid.stdout.is_empty());
    let error = String::from_utf8(invalid.stderr).unwrap();
    assert!(error.contains("unknown argument --unknown-option"), "{error}");
    assert!(error.contains("usage: scarpe-native"), "{error}");
}

#[cfg(target_os = "windows")]
#[test]
fn windows_renderer_does_not_request_a_console() {
    // Inspect the actual executable without opening a window. PE32 and PE32+ both put the
    // Subsystem field 68 bytes into the optional header, after the PE signature and COFF header.
    let exe = std::fs::read(env!("CARGO_BIN_EXE_scarpe-native")).expect("read the renderer");
    assert_eq!(&exe[..2], b"MZ");
    let pe = u32::from_le_bytes(exe[0x3c..0x40].try_into().unwrap()) as usize;
    assert_eq!(&exe[pe..pe + 4], b"PE\0\0");
    let optional = pe + 4 + 20;
    let magic = u16::from_le_bytes(exe[optional..optional + 2].try_into().unwrap());
    assert!(matches!(magic, 0x10b | 0x20b), "PE32 or PE32+ optional header");
    let subsystem = u16::from_le_bytes(exe[optional + 68..optional + 70].try_into().unwrap());
    assert_eq!(subsystem, 2, "IMAGE_SUBSYSTEM_WINDOWS_GUI, not a console executable");
}
