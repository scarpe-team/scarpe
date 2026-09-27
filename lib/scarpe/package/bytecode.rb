# frozen_string_literal: true

require "fileutils"

module Scarpe
  class Package
    # Precompiled Ruby for packaged native apps (DESIGN 11, the bootsnap trick). At package time
    # the bundled Ruby compiles Lacci, the native shim, the app and the libraries they load into
    # RubyVM::InstructionSequence binaries. At boot, RubyVM::InstructionSequence.load_iseq hands
    # those to require and load, so Ruby skips parsing and compiling that source again.
    #
    # An instruction sequence remembers the path it was compiled for, and __FILE__, __dir__,
    # require_relative and backtraces all read it. So the binaries are compiled for the place the
    # app will be installed (/Applications/Name.app unless the packager is told otherwise). An app
    # run from anywhere else, by another Ruby, or after a source file changed loads from source,
    # the way it always has.
    #
    # This file ships inside the bundle and is loaded before anything else, so it needs only core Ruby.
    module Bytecode
      DIR = "bytecode"
      MANIFEST = "manifest"
      SUFFIX = ".iseq"

      class << self
        attr_reader :loader

        # Boot time: sends require and load to the binaries, when they were compiled for this place
        # and this Ruby. Returns whether it did.
        def install(resources)
          @loader = Loader.for(resources)
          return false unless @loader

          loader = @loader
          RubyVM::InstructionSequence.define_singleton_method(:load_iseq) { |path| loader.load(path) }
          true
        end

        # Package time, inside the bundled Ruby: compiles everything the block loads that lives in
        # the bundle, plus every .rb under dirs (paths relative to resources).
        def compile_bundle(resources, installed_resources, dirs:)
          before = $LOADED_FEATURES.dup
          yield if block_given?
          loaded = ($LOADED_FEATURES - before).filter_map { |feature| relative(feature, resources) }
          everything = dirs.flat_map { |dir| Dir.glob("#{dir}/**/*.rb", base: resources) }
          compile(resources, installed_resources, (loaded + everything).uniq.sort)
        end

        # Compiles files (relative to resources) for the day resources sits at installed_resources.
        # Writes one binary per file and the manifest; returns the files that compiled.
        def compile(resources, installed_resources, files)
          out = File.join(resources, DIR)
          compiled = files.select { |file| compile_file(resources, installed_resources, file, out) }
          FileUtils.mkdir_p(out)
          File.write(File.join(out, MANIFEST), [installed_resources, RUBY_REVISION, *compiled].join("\n") << "\n")
          compiled
        end

        # What a binary must carry to stand in for the source at path: the Ruby that compiled it,
        # the path it was compiled for, and the size and mtime of the source it came from.
        def stamp(path, stat)
          [RUBY_REVISION, path, stat.size, stat.mtime.to_i].join("\n")
        end

        private

        def compile_file(resources, installed_resources, file, out)
          source = File.join(resources, file)
          installed = File.join(installed_resources, file)
          code = File.read(source, encoding: Encoding::UTF_8)
          iseq = RubyVM::InstructionSequence.compile(code, installed, installed, 1)
          binary = File.join(out, file + SUFFIX)
          FileUtils.mkdir_p(File.dirname(binary))
          File.binwrite(binary, iseq.to_binary(stamp(installed, File.stat(source))))
          true
        rescue SyntaxError, StandardError => e
          warn("scarpe package: #{file} stays source (#{e.class}: #{e.message.lines.first&.strip})")
          false
        end

        def relative(feature, resources)
          prefix = resources.end_with?("/") ? resources : "#{resources}/"
          feature.delete_prefix(prefix) if feature.end_with?(".rb") && feature.start_with?(prefix)
        end
      end

      # Finds the binary for a path Ruby is about to load, and checks it still stands for that source.
      class Loader
        attr_reader :hits, :misses

        # A loader for resources, or nil when its binaries were compiled for somewhere else or by
        # another Ruby (or there are none).
        def self.for(resources)
          installed_resources, revision, *files = File.readlines(File.join(resources, DIR, MANIFEST), chomp: true)
          new(resources, files) if installed_resources == resources && revision == RUBY_REVISION
        rescue SystemCallError
          nil
        end

        def initialize(resources, files)
          @binaries = files.to_h { |file| [File.join(resources, file), File.join(resources, DIR, file + SUFFIX)] }
          @hits = 0
          @misses = 0
        end

        # The compiled InstructionSequence for path, or nil to have Ruby compile the source.
        def load(path)
          binary_path = @binaries[path]
          return unless binary_path

          iseq = load_binary(path, binary_path)
          iseq ? @hits += 1 : @misses += 1
          iseq
        end

        private

        def load_binary(path, binary_path)
          binary = File.binread(binary_path)
          return unless RubyVM::InstructionSequence.load_from_binary_extra_data(binary) == Bytecode.stamp(path, File.stat(path))

          RubyVM::InstructionSequence.load_from_binary(binary)
        rescue StandardError
          nil
        end
      end
    end
  end
end
