# frozen_string_literal: true

module Scarpe
  module CLI
    DEFAULT_USAGE = <<~'USAGE'
      Usage: scarpe_core [OPTIONS] <scarpe app file>           # Same as "scarpe run"
             scarpe_core [OPTIONS] run <scarpe app file>
             scarpe_core [OPTIONS] env                         # print Scarpe environment settings
             scarpe_core -v                                    # print the Scarpe gem version and exit
        Options:
            --dev                          Use development local scarpe, not an installed gem
            --debug                        Turn on application debug mode
    USAGE

    def version_check
      if RUBY_VERSION[0..2] < "3.2"
        raise "Scarpe and Lacci require Ruby 3.2 or higher!"
      end
    end

    def env_or_default(env_var, default_val)
      [env_var, ENV[env_var] ? ENV[env_var].inspect : default_val]
    end

    def default_env_categories
      require "shoes"
      {
        "Lacci" => [
          env_or_default("SCARPE_DISPLAY_SERVICE", "(none)"),
          env_or_default("SCARPE_LOG_CONFIG", "(default)#{Shoes::Log::DEFAULT_LOG_CONFIG.inspect}"),
        ],
        "Ruby and Shell" => [
          ["RUBY_DESCRIPTION", RUBY_DESCRIPTION],
          ["RUBY_PLATFORM", RUBY_PLATFORM],
          ["RUBY_ENGINE", RUBY_ENGINE],
          env_or_default("SHELL", "(none)"),
          env_or_default("PATH", "(none)"),
          env_or_default("LD_LIBRARY_PATH", "(none)"),
          env_or_default("DYLD_LIBRARY_PATH", "(none)"),
          env_or_default("GEM_ROOT", "(none)"),
          env_or_default("GEM_HOME", "(none)"),
          env_or_default("GEM_PATH", "(none)"),
        ],
      }
    end

    def env_categories
      @env_categories ||= default_env_categories
      @env_categories
    end

    def add_env_categories(categories)
      unless categories.is_a?(Hash)
        raise("Please supply a hash with categories names as keys and an array of two-elt arrays as values!")
      end

      # Try to get categories into the *start* of the hash, insertion-order-wise
      @env_categories = categories.merge(env_categories)
    end

    def print_env
      env_categories.each do |category, entries|
        puts "#{category} environment:"
        entries.each do |name, val|
          puts "  #{name}: #{val}"
        end
      end
    end
  end
end
