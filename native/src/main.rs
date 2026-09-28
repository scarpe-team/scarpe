//! scarpe-native [--headless] [--scale F] [--fonts system|bundled] [--trace]
//!               [--exit-after SECS] [--inactive] [--ghost]

use scarpe_native::runtime::Options;
use scarpe_native::text::FontMode;
use std::time::Duration;

const USAGE: &str = "usage: scarpe-native [--headless] [--scale F] [--fonts system|bundled] [--trace] [--exit-after SECS] [--inactive] [--ghost]";

fn main() {
    let mut opts = Options { headless: false, scale: None, fonts: FontMode::System, trace: false };
    let mut exit_after = None;
    let mut inactive = std::env::var_os("SCARPE_NATIVE_INACTIVE").is_some();
    let mut ghost = switched_on("SCARPE_NATIVE_GHOST");
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--headless" => opts.headless = true,
            "--trace" => opts.trace = true,
            "--inactive" => inactive = true,
            "--ghost" => ghost = true,
            "--scale" => opts.scale = Some(value(&mut args, "--scale")),
            "--exit-after" => exit_after = Some(Duration::from_secs_f64(value(&mut args, "--exit-after"))),
            "--fonts" => {
                opts.fonts = match args.next().as_deref() {
                    Some("bundled") => FontMode::Bundled,
                    Some("system") => FontMode::System,
                    other => fail(&format!("--fonts takes system or bundled, not {other:?}")),
                }
            }
            "--version" => {
                println!("scarpe-native {}", env!("CARGO_PKG_VERSION"));
                return;
            }
            "--help" | "-h" => {
                println!("{USAGE}");
                return;
            }
            other => fail(&format!("unknown argument {other}")),
        }
    }
    let code = if opts.headless {
        scarpe_native::headless::run(opts, exit_after)
    } else {
        // A debug run that exits by itself must not steal focus either.
        let window_opts = scarpe_native::window::WindowOptions { exit_after, inactive: inactive || exit_after.is_some(), ghost };
        scarpe_native::window::run(opts, window_opts)
    };
    std::process::exit(code);
}

/// Set, and not "0", "false" or "no" (the shim's truthy_env?).
fn switched_on(var: &str) -> bool {
    std::env::var(var).is_ok_and(|v| !matches!(v.trim().to_ascii_lowercase().as_str(), "" | "0" | "false" | "no"))
}

fn value<T: std::str::FromStr>(args: &mut impl Iterator<Item = String>, flag: &str) -> T {
    args.next().and_then(|v| v.parse().ok()).unwrap_or_else(|| fail(&format!("{flag} needs a number")))
}

fn fail(msg: &str) -> ! {
    eprintln!("scarpe-native: {msg}\n{USAGE}");
    std::process::exit(2);
}
