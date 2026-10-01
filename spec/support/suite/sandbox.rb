# frozen_string_literal: true

module SpecSuite
  # A throwaway directory per case or example: its own HOME, LOCALAPPDATA, working directory,
  # temp dir and download cache, so apps that write to LIB_DIR, ~, cwd or TMPDIR never touch
  # the real machine or the next case. Also builds the child environment from scratch (spawned
  # with unsetenv_others).
  class Sandbox
    attr_reader :root

    # Readable, and unique even for cases whose names differ only in characters a directory
    # name cannot keep: check.checked?.sspec and check.checked=.sspec both flatten to "_".
    def self.dir_name(relative_path)
      "#{relative_path.gsub(/[^\w.-]+/, "_")}-#{Zlib.crc32(relative_path).to_s(16)}"
    end

    def initialize(parent, name)
      @root = File.join(parent, name)
      FileUtils.mkdir_p([home, local_app_data, work])
      FileUtils.mkdir_p(tmp, mode: 0o700)
    end

    def home = File.join(root, "home")
    def local_app_data = File.join(root, "localappdata")
    def work = File.join(root, "work")
    def tmp = File.join(root, "tmp")
    def download_cache = File.join(root, "cache")
    def renderer_pid_file = File.join(root, "renderer.pid")
    def trap_file = File.join(root, "trapped_commands.txt")
    def clipboard_file = File.join(root, "clipboard.txt")
    def log = File.join(root, "output.log")

    def path(name)
      File.join(work, name)
    end

    def write(name, contents)
      File.write(path(name), contents)
      path(name)
    end

    def copy_assets
      FileUtils.cp_r(ASSETS_DIR, path("assets")) if Dir.exist?(ASSETS_DIR)
    end

    # Commands the fakebin trap caught, e.g. ["osascript -e display dialog ..."].
    def trapped_commands
      File.exist?(trap_file) ? File.readlines(trap_file, chomp: true) : []
    end

    def env(display, extra = {})
      base_env.merge(DisplayEnv.for(display)).merge(extra.transform_values { |value| value&.to_s })
    end

    def remove
      FileUtils.rm_rf(root)
    end

    private

    def base_env
      {
        "PATH" => [FAKEBIN, ENV.fetch("PATH", "/usr/bin:/bin")].join(File::PATH_SEPARATOR),
        "HOME" => home,
        "LOCALAPPDATA" => local_app_data,
        "TMPDIR" => tmp,
        "SCARPE_NATIVE_CACHE" => download_cache,
        "SCARPE_NATIVE_PID_FILE" => renderer_pid_file,
        "LANG" => ENV.fetch("LANG", "en_US.UTF-8"),
        "BUNDLE_GEMFILE" => File.join(REPO, "Gemfile"),
        "RUBYOPT" => "-r#{BUILTIN_STUB}",
        "SPEC_TRAP_FILE" => trap_file,
        "SPEC_CLIPBOARD_FILE" => clipboard_file,
        "SCARPE_CLIPBOARD_FILE" => clipboard_file,
        "SCARPE_NATIVE_SNAPSHOT_DIR" => File.join(RESULTS_DIR, "snapshots"),
      }.merge(ToolchainEnv.passthrough).merge(windows_env)
    end

    # Windows programs need a few of the system's own variables (Winsock, for one, will not start
    # without SystemRoot), and look for temp and home under Windows' names. Windows matches names in
    # any case, and MSYS bash (the CI shell) hands them on upper-cased.
    WINDOWS_SYSTEM_ENV = %w[SystemRoot windir SystemDrive ComSpec PATHEXT NUMBER_OF_PROCESSORS PROCESSOR_ARCHITECTURE OS].freeze

    def windows_env
      return {} unless Gem.win_platform?

      system = ENV.to_h.select { |name, _| WINDOWS_SYSTEM_ENV.any? { |wanted| wanted.casecmp?(name) } }
      system.merge("TEMP" => tmp, "TMP" => tmp, "USERPROFILE" => home)
    end
  end

  module DisplayEnv
    def self.for(display)
      case display
      when "niente"
        { "SCARPE_DISPLAY_SERVICE" => "niente", "NIENTE_LOG_LEVEL" => "warn" }
      when "native"
        {
          "SCARPE_DISPLAY_SERVICE" => "native", "SCARPE_NATIVE_HEADLESS" => "1",
          # The shim hands SCARPE_NATIVE_ARGS to the binary; bundled fonts make layout identical everywhere.
          "SCARPE_NATIVE_ARGS" => [ENV["SCARPE_NATIVE_ARGS"], "--fonts bundled"].compact.join(" "),
        }.merge(NativeBinary.env)
      else
        raise ArgumentError, "unknown display #{display.inspect}"
      end
    end
  end

  # HOME moves into the sandbox, so point Rust and mise at the real toolchains explicitly:
  # a rustup that cannot find its home would try to install one.
  module ToolchainEnv
    REAL_HOME = Dir.home

    def self.passthrough
      {
        "CARGO_HOME" => ENV.fetch("CARGO_HOME", File.join(REAL_HOME, ".cargo")),
        "RUSTUP_HOME" => ENV.fetch("RUSTUP_HOME", File.join(REAL_HOME, ".rustup")),
        "RUST_BACKTRACE" => "1",
      }
    end
  end

  # The native display finds its binary through SCARPE_NATIVE_BIN (DESIGN 5.2). We build it
  # once before a native run so parallel cases never race to run cargo.
  module NativeBinary
    CRATE = File.join(REPO, "native")
    RELEASE_BIN = File.join(CRATE, "target", "release", "scarpe-native#{RbConfig::CONFIG["EXEEXT"]}")

    class << self
      def prepare(build: true)
        return if ENV["SCARPE_NATIVE_BIN"]
        return unless build && File.exist?(File.join(CRATE, "Cargo.toml"))

        $stderr.puts "spec/run: cargo build --release (native/)"
        env = ToolchainEnv.passthrough
        ok = system(env, "cargo", "build", "--release", "--quiet", chdir: CRATE)
        abort "spec/run: cargo build failed; fix the build or pass --no-build" unless ok
      end

      def env
        bin = ENV["SCARPE_NATIVE_BIN"] || (RELEASE_BIN if File.exist?(RELEASE_BIN))
        bin ? { "SCARPE_NATIVE_BIN" => bin } : {}
      end
    end
  end
end
