# frozen_string_literal: true

require_relative "helper"
require "scarpe/package/bytecode"

# Precompiled Ruby for packaged apps: compiled for the place the app will be installed, loaded
# through RubyVM::InstructionSequence.load_iseq, and source again whenever anything does not match.
class BytecodeTest < Minitest::Test
  include PackageTestHelpers

  Bytecode = Scarpe::Package::Bytecode

  def setup
    @resources = scratch_dir
  end

  def test_a_compiled_file_loads_from_its_binary
    path = write(@resources, "lib/greeting.rb", "'hello from ' + __FILE__\n")
    Bytecode.compile(@resources, @resources, ["lib/greeting.rb"])

    loader = Bytecode::Loader.for(@resources)
    iseq = loader.load(path)

    assert_kind_of RubyVM::InstructionSequence, iseq
    assert_equal "hello from #{path}", iseq.eval
    assert_equal 1, loader.hits
  end

  def test_binaries_carry_the_path_the_app_will_run_from
    build = File.join(@resources, "build")
    installed = File.join(@resources, "installed")
    write(build, "lib/where.rb", "[__FILE__, __dir__]\n")
    Bytecode.compile(build, installed, ["lib/where.rb"])
    FileUtils.cp_r(build, installed, preserve: true)

    iseq = Bytecode::Loader.for(installed).load(File.join(installed, "lib/where.rb"))

    assert_equal [File.join(installed, "lib/where.rb"), File.join(installed, "lib")], iseq.eval
    assert_nil Bytecode::Loader.for(build), "the build directory is not where the binaries were compiled for"
  end

  def test_a_moved_bundle_loads_from_source
    write(@resources, "lib/a.rb", "1\n")
    Bytecode.compile(@resources, "/Applications/Moved.app/Contents/Resources", ["lib/a.rb"])

    assert_nil Bytecode::Loader.for(@resources)
    refute Bytecode.install(@resources)
  end

  def test_another_ruby_loads_from_source
    write(@resources, "lib/a.rb", "1\n")
    Bytecode.compile(@resources, @resources, ["lib/a.rb"])
    manifest = File.join(@resources, Bytecode::DIR, Bytecode::MANIFEST)
    lines = File.readlines(manifest)
    lines[1] = "a-revision-from-another-ruby\n"
    File.write(manifest, lines.join)

    assert_nil Bytecode::Loader.for(@resources)
  end

  def test_an_edited_source_loads_from_source
    path = write(@resources, "lib/a.rb", "1\n")
    Bytecode.compile(@resources, @resources, ["lib/a.rb"])
    File.write(path, "22\n")

    loader = Bytecode::Loader.for(@resources)
    assert_nil loader.load(path)
    assert_equal 1, loader.misses
  end

  def test_a_source_touched_since_loads_from_source
    path = write(@resources, "lib/a.rb", "1\n")
    Bytecode.compile(@resources, @resources, ["lib/a.rb"])
    later = File.mtime(path) + 60
    File.utime(later, later, path)

    assert_nil Bytecode::Loader.for(@resources).load(path)
  end

  def test_a_damaged_binary_loads_from_source
    path = write(@resources, "lib/a.rb", "1\n")
    Bytecode.compile(@resources, @resources, ["lib/a.rb"])
    File.binwrite(File.join(@resources, Bytecode::DIR, "lib/a.rb#{Bytecode::SUFFIX}"), "not an instruction sequence")

    assert_nil Bytecode::Loader.for(@resources).load(path)
  end

  def test_files_outside_the_manifest_are_left_to_ruby
    write(@resources, "lib/a.rb", "1\n")
    Bytecode.compile(@resources, @resources, ["lib/a.rb"])
    loader = Bytecode::Loader.for(@resources)

    assert_nil loader.load(File.join(@resources, "lib/elsewhere.rb"))
    assert_equal [0, 0], [loader.hits, loader.misses]
  end

  def test_a_file_that_does_not_compile_stays_source
    write(@resources, "app/broken.rb", "def oops(\n")
    write(@resources, "app/fine.rb", "1\n")

    compiled = nil
    _, err = capture_io { compiled = Bytecode.compile(@resources, @resources, %w[app/broken.rb app/fine.rb]) }

    assert_equal ["app/fine.rb"], compiled
    assert_match %r{app/broken.rb stays source}, err
    refute File.exist?(File.join(@resources, Bytecode::DIR, "app/broken.rb#{Bytecode::SUFFIX}"))
  end

  def test_compile_bundle_takes_what_boot_loads_and_everything_in_dirs
    library = "bytecode_test_library_#{Process.pid}"
    write(@resources, "runtime/lib/#{library}.rb", "module BytecodeTestLibrary; end\n")
    write(@resources, "runtime/lib/never_loaded.rb", "1\n")
    write(@resources, "app/app.rb", "1\n")
    write(@resources, "app/helpers/help.rb", "1\n")
    $LOAD_PATH.unshift(File.join(@resources, "runtime/lib"))

    compiled = Bytecode.compile_bundle(@resources, @resources, dirs: ["app"]) { require library }

    assert_equal ["app/app.rb", "app/helpers/help.rb", "runtime/lib/#{library}.rb"], compiled
  ensure
    $LOAD_PATH.delete(File.join(@resources, "runtime/lib"))
  end

  # The real hook, in a fresh Ruby: require and require_relative load the binaries, and
  # __FILE__ and __dir__ still say where the files are.
  def test_require_loads_the_binaries_through_load_iseq
    write(@resources, "lib/outer.rb", "require_relative 'inner'\nOUTER_DIR = __dir__\n")
    write(@resources, "lib/inner.rb", "INNER_FILE = __FILE__\n")
    Bytecode.compile(@resources, @resources, %w[lib/outer.rb lib/inner.rb])

    out = ruby_output(<<~RUBY, @resources)
      require "scarpe/package/bytecode"
      installed = Scarpe::Package::Bytecode.install(ARGV[0])
      $LOAD_PATH.unshift(File.join(ARGV[0], "lib"))
      require "outer"
      puts [installed, Scarpe::Package::Bytecode.loader.hits, OUTER_DIR, INNER_FILE].join("|")
    RUBY

    assert_equal ["true", "2", File.join(@resources, "lib"), File.join(@resources, "lib/inner.rb")], out.strip.split("|")
  end
end
