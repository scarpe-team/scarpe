# frozen_string_literal: true

require "rbconfig"

module WebviewRuby
  # Builds ext/<arch>-<os>/webview-ext the way `gem install` would.
  #
  # Scarpe uses this gem as a Bundler path: gem, and Bundler never compiles the
  # extensions of path: gems, so the library is built on first use instead.
  module Build
    EXT_DIR = File.expand_path("../../ext", __dir__)

    # Child-process script: load the MSYS2/MinGW toolchain on RubyInstaller
    # (which `gem install` does for us, but a plain process does not), then
    # run ext/Rakefile.
    RAKE_SCRIPT = <<~RUBY
      begin
        require "ruby_installer/runtime"
        RubyInstaller::Runtime.enable_msys_apps
      rescue LoadError
      end
      require "rake"
      # clobber first: the compile tasks only track the .cpp, not the headers it includes
      Rake.application.run(["-f", "Rakefile", "clobber", "default"])
    RUBY

    # True when a source under ext/ is newer than the built library, e.g. after a pull that
    # changed a vendored header.
    def self.stale?(library)
      built = File.mtime(library)
      sources = Dir[File.join(EXT_DIR, "{webview,webview-win}", "**", "*")] << File.join(EXT_DIR, "Rakefile")
      sources.any? { |f| File.file?(f) && File.mtime(f) > built }
    end

    def self.run
      warn "webview_ruby: compiling the native library in #{EXT_DIR} (once, and again when ext/ changes)..."
      unless system(RbConfig.ruby, "-e", RAKE_SCRIPT, chdir: EXT_DIR)
        raise LoadError, "webview_ruby: building the native library failed; see the compiler output above. " \
          "To retry by hand: cd #{EXT_DIR} && rake"
      end
    end
  end
end
