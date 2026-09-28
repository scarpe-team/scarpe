# frozen_string_literal: true

require "cgi/escape"

module SpecSuite
  # spec/results/gallery/index.html: every example with its native snapshot, its path, and
  # each display's status and error line, broken ones first. Built from the merged
  # examples-<display>.json files, so separate --examples runs add up to one page.
  class Gallery
    DISPLAYS = %w[native niente].freeze
    QUIET = %w[pass not_applicable].freeze

    def initialize(results_dir = RESULTS_DIR)
      @results_dir = results_dir
      @dir = File.join(results_dir, "gallery")
    end

    def write
      FileUtils.mkdir_p(@dir)
      path = File.join(@dir, "index.html")
      File.write(path, page)
      path
    end

    private

    def results
      @results ||= DISPLAYS.to_h { |display| [display, rows_for(display)] }.reject { |_, rows| rows.empty? }
    end

    def rows_for(display)
      file = File.join(@results_dir, "examples-#{display}.json")
      File.exist?(file) ? JSON.parse(File.read(file)).fetch("results", {}) : {}
    rescue JSON::ParserError
      {}
    end

    def examples
      results.values.flat_map(&:keys).uniq.sort_by { |path| [broken?(path) ? 0 : 1, path] }
    end

    def broken?(path)
      results.values.any? { |rows| BAD_STATUSES.include?(rows.dig(path, "status")) }
    end

    def page
      <<~HTML
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Scarpe examples</title>
        <style>#{STYLE}</style>
        </head>
        <body>
        <header>
        <h1>Scarpe examples</h1>
        <p>#{summary}. Written #{escape(Time.now.utc.strftime("%Y-%m-%d %H:%M UTC"))} by <code>spec/run --examples</code>; broken examples first.</p>
        </header>
        <main>
        #{examples.map { |path| card(path) }.join("\n")}
        </main>
        </body>
        </html>
      HTML
    end

    def summary
      results.map do |display, rows|
        counts = rows.values.map { |row| row["status"] }.tally.sort_by { |status, _| STATUSES.index(status) || STATUSES.size }
        "#{display}: " + counts.map { |status, count| "#{count} #{status.tr("_", " ")}" }.join(", ")
      end.join("; ")
    end

    def card(path)
      <<~HTML
        <article#{' class="broken"' if broken?(path)}>
        #{thumbnail(path)}
        <h2>#{escape(path)}</h2>
        #{results.map { |display, rows| status_line(display, rows[path]) }.join("\n")}
        </article>
      HTML
    end

    def thumbnail(path)
      image = "#{ExampleList.slug(path)}.png"
      return %(<div class="shot none">no snapshot</div>) unless File.exist?(File.join(@dir, image))

      src = url(image)
      %(<a class="shot" href="#{src}"><img src="#{src}" alt="#{escape(path)}" loading="lazy"></a>)
    end

    def status_line(display, row)
      return %(<p class="status"><b>#{display}</b> <span class="badge">not run</span></p>) unless row

      status = row["status"]
      message = row["message"] unless QUIET.include?(status)
      %(<p class="status"><b>#{display}</b> <span class="badge #{status}">#{status.tr("_", " ")}</span></p>) +
        (message ? %(\n<pre>#{escape(message)}</pre>) : "")
    end

    def escape(text) = CGI.escapeHTML(text.to_s)

    def url(name)
      name.b.gsub(/[^A-Za-z0-9_.~-]/n) { |byte| format("%%%02X", byte.ord) }
    end

    STYLE = <<~CSS
      :root { --bg: #fafafa; --card: #fff; --ink: #1d1d1f; --muted: #6e6e73; --line: #e2e2e7;
        --pass: #1f7a3d; --bad: #b3261e; --soft: #8a6d00; }
      @media (prefers-color-scheme: dark) {
        :root { --bg: #161618; --card: #1f1f22; --ink: #f2f2f5; --muted: #a1a1a8; --line: #333338;
          --pass: #5cc98a; --bad: #ff8a80; --soft: #e0c060; }
      }
      * { box-sizing: border-box; }
      body { margin: 0; padding: 24px 16px; background: var(--bg); color: var(--ink);
        font: 14px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
      header { max-width: 1200px; margin: 0 auto 20px; }
      h1 { font-size: 22px; margin: 0 0 4px; }
      header p { margin: 0; color: var(--muted); }
      main { max-width: 1200px; margin: 0 auto; display: grid; gap: 16px;
        grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); }
      article { background: var(--card); border: 1px solid var(--line); border-radius: 10px; padding: 12px;
        min-width: 0; }
      article.broken { border-color: var(--bad); }
      .shot { display: block; aspect-ratio: 4 / 3; border-radius: 6px; overflow: hidden; background: var(--bg);
        border: 1px solid var(--line); }
      .shot img { width: 100%; height: 100%; object-fit: contain; display: block; }
      .shot.none { display: grid; place-items: center; aspect-ratio: auto; height: 40px; color: var(--muted); font-size: 12px; }
      h2 { font-size: 13px; font-weight: 600; margin: 10px 0 6px; overflow-wrap: anywhere; }
      .status { margin: 4px 0; }
      .status b { display: inline-block; width: 52px; font-weight: 500; color: var(--muted); }
      .badge { font-size: 12px; padding: 1px 7px; border-radius: 9px; border: 1px solid currentColor; color: var(--muted); }
      .badge.pass { color: var(--pass); }
      .badge.fail, .badge.error, .badge.timeout, .badge.unexpected_pass { color: var(--bad); }
      .badge.expected_fail, .badge.skip { color: var(--soft); }
      pre { margin: 4px 0 8px; padding: 6px 8px; background: var(--bg); border-radius: 6px; font-size: 12px;
        white-space: pre-wrap; overflow-wrap: anywhere; }
    CSS
  end
end
