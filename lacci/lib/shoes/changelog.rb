# frozen_string_literal: true

require_relative "log"
# require "scarpe/components/modular_logger"

class Shoes
  class Changelog
    # include Shoes::Log

    def initialize
      #TODO : refer to  https://github.com/scarpe-team/scarpe/pull/400
      #       and figure out how to use scarpe logger here without getting duplicate or nil error
      # Shoes::Log.instance = Scarpe::Components::ModularLogImpl.new
      # log_init("Changelog")
    end

    # root_dir duplicates constants.rb, but how to share?
    def get_latest_release_info(root_dir = File.dirname(__FILE__, 4))
      revision = git_revision(root_dir)

      changelog_file = "#{root_dir}/CHANGELOG.md"
      if File.exist?(changelog_file)
        # UTF-8 whatever the locale: a packaged app starts with no LANG, where Ruby reads US-ASCII.
        changelog_content = File.read(changelog_file, encoding: Encoding::UTF_8)
        release_name_pattern = /^## \[(\d+\.\d+\.\d+)\] - (\d{4}-\d{2}-\d{2}) - (\w+)$/m
        release_matches = changelog_content.scan(release_name_pattern)
        latest_release = release_matches.max_by { |version, _date, _name| Gem::Version.new(version) }

        if latest_release
          #puts "Found release #{latest_release[0]} in CHANGELOG.md"
          # @log.debug("Found release #{latest_release[0]} in CHANGELOG.md") # Logger isn't initialized yet
          version_parts = latest_release[0].split(".").map(&:to_i)
          rel_id = ("%02d%02d%02d" % version_parts).to_i

          return({
            RELEASE_NAME: latest_release[2],
            RELEASE_BUILD_DATE: latest_release[1],
            RELEASE_ID: rel_id,
            REVISION: revision,
          })
        end
      end

      puts "No release found in CHANGELOG.md"
      { RELEASE_NAME: nil, RELEASE_BUILD_DATE: nil, RELEASE_ID: nil, REVISION: revision }
    end

    private

    COMMIT = /\A\h{40}(\h{24})?\z/

    # The checkout's commit, read from the checkout itself rather than from wherever the
    # app runs (ledger L3), or nil outside a git checkout (a packaged app). It reads the
    # .git files instead of running git, which would cost a process at every require.
    def git_revision(root_dir)
      git_dir = git_dir_in(root_dir) or return nil
      head = File.read(File.join(git_dir, "HEAD")).strip
      ref = head.delete_prefix("ref: ")
      return head[COMMIT] if ref == head

      common_dir = common_dir_of(git_dir)
      loose_ref(git_dir, ref) || loose_ref(common_dir, ref) || packed_ref(common_dir, ref)
    rescue SystemCallError
      nil
    end

    # A checkout's .git is a directory, or in a worktree a file saying "gitdir: <path>".
    def git_dir_in(root_dir)
      dot_git = File.join(root_dir, ".git")
      return dot_git if File.directory?(dot_git)
      return unless File.file?(dot_git)

      pointer = File.read(dot_git)[/\Agitdir: (.+)$/, 1]
      pointer && File.expand_path(pointer.strip, root_dir)
    end

    # Branches live in the main repository's git dir, which a worktree names in commondir.
    def common_dir_of(git_dir)
      pointer = File.join(git_dir, "commondir")
      File.file?(pointer) ? File.expand_path(File.read(pointer).strip, git_dir) : git_dir
    end

    def loose_ref(dir, ref)
      path = File.join(dir, ref)
      File.file?(path) ? File.read(path).strip[COMMIT] : nil
    end

    def packed_ref(dir, ref)
      path = File.join(dir, "packed-refs")
      return unless File.file?(path)

      File.foreach(path) do |line|
        commit, name = line.split
        return commit[COMMIT] if name == ref
      end
      nil
    end
  end
end
