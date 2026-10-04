#![windows_subsystem = "windows"]

// A native Windows package's entry point. All paths are relative to this executable, so the
// extracted folder can move. No installed Ruby, Bundler, shell or WebView2 is involved.
use std::{
    env,
    fs::{self, OpenOptions},
    io::{self, Write},
    os::windows::process::CommandExt,
    path::PathBuf,
    process::{self, Command, Stdio},
};

#[link(name = "user32")]
extern "system" {
    fn MessageBoxW(
        window: *mut std::ffi::c_void,
        text: *const u16,
        title: *const u16,
        flags: u32,
    ) -> i32;
}

fn log_path() -> PathBuf {
    let exe = env::current_exe().unwrap_or_else(|_| PathBuf::from("Scarpe.exe"));
    env::var_os("LOCALAPPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(env::temp_dir)
        .join(exe.file_stem().unwrap_or_default())
        .join("launcher.log")
}

fn report_error(reason: &str) {
    let path = log_path();
    let message = format!(
        "Could not run the application.\n\n{reason}\n\nLog: {}",
        path.display()
    );
    eprintln!("{message}");
    if let Ok(mut log) = OpenOptions::new().create(true).append(true).open(&path) {
        let _ = writeln!(log, "{message}");
    }
    if env::var("SCARPE_NATIVE_HEADLESS").as_deref() != Ok("1") {
        let text: Vec<u16> = message.encode_utf16().chain(Some(0)).collect();
        let title: Vec<u16> = "Application startup error"
            .encode_utf16()
            .chain(Some(0))
            .collect();
        unsafe {
            MessageBoxW(
                std::ptr::null_mut(),
                text.as_ptr(),
                title.as_ptr(),
                0x00000010,
            )
        };
    }
}

fn launch() -> io::Result<i32> {
    let exe = env::current_exe()?;
    let root = exe
        .parent()
        .ok_or_else(|| io::Error::other("Missing application directory"))?;
    let runtime = root.join("ruby");
    let ruby = runtime.join("bin.real/ruby.exe");
    let renderer = root.join("scarpe-native.exe");
    let boot = root.join("boot.rb");
    let log_path = log_path();
    fs::create_dir_all(log_path.parent().unwrap())?;
    let log = OpenOptions::new()
        .create(true)
        .append(true)
        .open(log_path)?;
    if !ruby.is_file()
        || !renderer.is_file()
        || !boot.is_file()
        || !root.join("app/main.rb").is_file()
    {
        return Err(io::Error::new(
            io::ErrorKind::NotFound,
            "Application files are missing. Extract the whole ZIP before opening the application.",
        ));
    }

    // Keep these source and gem paths in step with Native#runtime_env. Ruby needs its own
    // standard-library paths explicitly because Traveling Ruby was compiled elsewhere.
    let mut paths: Vec<PathBuf> = [
        "lib",
        "lacci/lib",
        "scarpe-components/lib",
        "gems/fastimage/lib",
        "gems/base64/lib",
    ]
    .iter()
    .map(|path| root.join("scarpe").join(path))
    .collect();
    let abi = env!("SCARPE_PACKAGE_RUBY_ABI");
    for path in [
        format!("site_ruby/{abi}"),
        format!("site_ruby/{abi}/x64-mingw-ucrt"),
        "site_ruby".into(),
        format!("vendor_ruby/{abi}"),
        format!("vendor_ruby/{abi}/x64-mingw-ucrt"),
        "vendor_ruby".into(),
        abi.into(),
        format!("{abi}/x64-mingw-ucrt"),
    ] {
        paths.push(runtime.join("lib/ruby").join(path));
    }
    let mut command = Command::new(ruby);
    command
        .args(env!("SCARPE_PACKAGE_RUBY_FLAGS").split_whitespace())
        .arg(boot)
        .arg("main.rb")
        .args(env::args_os().skip(1))
        .env("RUBYLIB", env::join_paths(paths).map_err(io::Error::other)?)
        .env("GEM_HOME", root.join("runtime/gems"))
        .env("GEM_PATH", root.join("runtime/gems"))
        .env("SCARPE_DISPLAY_SERVICE", "native")
        .env("SCARPE_NATIVE_BIN", renderer)
        .env("SCARPE_LAUNCHER", &exe)
        .env("SSL_CERT_FILE", runtime.join("lib/ca-bundle.crt"))
        .env_remove("SSL_CERT_DIR")
        .env_remove("RUBYOPT")
        .env_remove("BUNDLE_GEMFILE")
        .env_remove("BUNDLE_PATH")
        .env_remove("BUNDLE_BIN_PATH")
        .env_remove("BUNDLER_SETUP")
        .current_dir(root.join("app"))
        // A hidden console can still impose a legacy code page on Ruby. A detached process
        // uses Ruby's UTF-8 manifest from startup, including when the folder has an Arabic name.
        .creation_flags(0x00000008) // DETACHED_PROCESS
        .stdin(Stdio::null())
        .stdout(log.try_clone()?)
        .stderr(log);
    Ok(command.status()?.code().unwrap_or(1))
}

fn main() {
    let code = match launch() {
        Ok(0) => return,
        Ok(code) => {
            report_error(&format!(
                "Application exited with code {code} (0x{:08X}).",
                code as u32
            ));
            code
        }
        Err(error) => {
            report_error(&error.to_string());
            1
        }
    };
    process::exit(code);
}
