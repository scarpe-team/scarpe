# frozen_string_literal: true

module SpecSuite
  # spec/examples.yml: every example under examples/ with what we expect of it.
  #
  #   examples/button.rb: {category: ".", needs: [dialog], status: loads}
  #
  # status is `loads` (must load cleanly), `fails` (known broken; `reason:` says why) or
  # `skip` (not run: side effects, missing gems, Shoes 3 only). Like a case's `expect:`, it can
  # be a Hash by display: {niente: loads, native: fails}. Optional `steps:` drive
  # `scarpe peek` under native, in order: [{click: "OK"}, {type: "hello"}, {key: "return"}].
  # Optional `dialogs:` answer dialogs on both displays: {confirm: true, ask_color: "#f80"}.
  # Optional `pixels:` are colours the native snapshot must show: [[26, 27, "#ac7672"]].
  # Optional `ruby:` is the Ruby versions the status holds on (">= 4.0"); on any other Ruby the
  # example must load. For a failure that comes from a library Ruby moved or removed, so CI's
  # oldest and newest Rubies can both run the same list.
  class ExampleList
    Example = Struct.new(:path, :category, :needs, :status, :reason, :steps, :wait, :dialogs, :pixels, :ruby, keyword_init: true) do
      def status_on(display, ruby_version: RUBY_VERSION)
        return "loads" if ruby && !Gem::Requirement.new(ruby).satisfied_by?(Gem::Version.new(ruby_version))

        status.is_a?(Hash) ? status.fetch(display, "loads") : status
      end

      def slug = ExampleList.slug(path)
    end

    STATUSES = %w[loads fails skip].freeze

    # The file name stem of an example's sandbox and gallery snapshot.
    def self.slug(path)
      path.delete_prefix("examples/").delete_suffix(".rb").gsub("/", "__")
    end

    def self.load(file = EXAMPLES_YML)
      new(YAML.safe_load_file(file) || {})
    end

    def initialize(rows)
      @examples = rows.map do |path, fields|
        fields ||= {}
        Example.new(path:, category: fields["category"], needs: fields["needs"] || [], status: fields["status"] || "loads",
          reason: fields["reason"], steps: fields["steps"] || [], wait: fields["wait"], dialogs: fields["dialogs"],
          pixels: fields["pixels"] || [], ruby: fields["ruby"])
      end
    end

    def select(filters)
      return @examples if filters.empty?

      @examples.select do |example|
        filters.any? { |filter| example.path == filter || example.path.start_with?(filter.chomp("/") + "/") }
      end
    end

    def problems
      @examples.flat_map do |example|
        statuses = example.status.is_a?(Hash) ? example.status.values : [example.status]
        (statuses - STATUSES).map { |bad| "#{example.path}: status #{bad.inspect} is not one of #{STATUSES.join(", ")}" } +
          ruby_problems(example)
      end
    end

    private

    def ruby_problems(example)
      return [] if example.ruby.nil?

      Gem::Requirement.new(example.ruby)
      []
    rescue Gem::Requirement::BadRequirementError, TypeError
      ["#{example.path}: ruby #{example.ruby.inspect} is not a version requirement like \">= 4.0\""]
    end
  end
end
