# frozen_string_literal: true

class Shoes
  # The manual in a window of its own, as Shoes 3's built-in manual was ("This manual is a
  # Shoes program itself!", manual 31; ledger K7): the chapters and their sections down the
  # left, the chosen section on the right, drawn from docs/static/manual.md. Nothing opens a
  # browser, so an app made for children keeps them in it; Hackety Hack's Help tab calls
  # Shoes.show_manual.
  class Manual
    FILE = File.expand_path("../../../docs/static/manual.md", __dir__)
    TITLE = "The Shoes Manual"

    # A chapter's opening words, or one of its sections.
    Section = Struct.new(:chapter, :title, :lines)

    # Inline marks the manual uses: `'emphasis`', `code`, __strong__, [[links]], pictures.
    INLINE = /(`'.+?`'|`[^`]+`|__.+?__|\*\*.+?\*\*|\[\[[^\]]+\]\]|!\[[^\]]*\]\([^)]*\))/
    # A picture, ![man-app.png](man-app.png); its file sits beside the manual.
    PICTURE = /!\[[^\]]*\]\(([^)]+)\)/
    # Shoes 3's manual drew these where the text holds them (help.rb color_page, index_page and
    # sample_page; ledger M38).
    PLACEHOLDERS = { "{COLORS}" => :colors, "{INDEX}" => :index, "{SAMPLES}" => :samples }.freeze

    class << self
      # The manual cut into sections, in order, without the page's front matter. It is UTF-8,
      # whatever the locale says: an app started from Finder has none, and reads US-ASCII.
      def sections(text = File.read(FILE, encoding: Encoding::UTF_8))
        text.sub(/\A---\n.*?\n---\n/m, "").each_line(chomp: true).each_with_object([]) do |line, sections|
          if (chapter = line[/\A# (.+)/, 1])
            sections << Section.new(chapter, chapter, [])
          elsif (title = line[/\A## (.+)/, 1])
            sections << Section.new(sections.last&.chapter, title, [])
          else
            sections.last&.lines&.push(line)
          end
        end
      end

      # Opens the manual at the section called `name`, or at its first page, in a window of
      # its own beside the app that asked, or as the app when none is running.
      def show(name = nil)
        return alert("The manual did not come with this copy of Shoes.") unless File.exist?(FILE)

        sections = self.sections
        first = sections.find { |s| s.title.casecmp?(name.to_s) } || sections.first
        draw = proc { Shoes::Manual.new(self, sections).draw(first) }
        styles = { title: TITLE, width: 760, height: 560 }
        opener = Shoes.APPS.last
        opener ? opener.window(**styles, &draw) : Shoes.app(**styles, &draw)
      end
    end

    def initialize(app, sections)
      @app = app
      @sections = sections
    end

    # The Shoes calls below are the app's: the blocks here keep this object as self (ledger B1).
    def method_missing(name, *args, **kwargs, &block)
      return super unless @app.respond_to?(name)

      @app.public_send(name, *args, **kwargs, &block)
    end

    def respond_to_missing?(name, include_private = false)
      @app.respond_to?(name) || super
    end

    def draw(section)
      background "#f7f4ec"
      flow width: 1.0, height: 1.0 do
        stack width: 210, height: 1.0, scroll: true do
          background "#e9e3d3"
          @sections.chunk_while { |a, b| a.chapter == b.chapter }.each { |chapter| index(chapter) }
        end
        @page = stack width: -210, height: 1.0, scroll: true
      end
      turn_to(section)
    end

    def turn_to(section)
      @page.clear do
        title section.title, size: 24, stroke: "#333", margin: [18, 16, 18, 10]
        blocks(section.lines).each { |kind, text| draw_block(kind, text) }
      end
      @page.scroll_top = 0
    end

    private

    def index(chapter)
      opening, *rest = chapter
      caption link(opening.chapter) { turn_to(opening) }, weight: "bold", margin: [12, 12, 8, 2]
      rest.each { |s| para link(s.title) { turn_to(s) }, size: 10, margin: [24, 1, 8, 1] }
    end

    # The section's lines as [kind, text] pairs: :heading, :code, :item or :para.
    def blocks(lines)
      out = []
      words = []
      code = nil
      finish_para = lambda do
        text = words.join(" ")
        words = []
        return if text.empty?
        return out << [PLACEHOLDERS[text]] if PLACEHOLDERS.key?(text)

        pictures = text.scan(PICTURE).flatten
        text = text.gsub(PICTURE, "").strip
        out << [:para, text] unless text.empty?
        pictures.each { |file| out << [:picture, file] }
      end
      lines.each do |line|
        if code && !line.start_with?("```")
          code << line.delete_prefix(" ")
        elsif code
          out << [:code, code.reject { |l| l.strip == "#!ruby" }.join("\n").rstrip]
          code = nil
        elsif line.start_with?("```")
          finish_para.call
          code = []
        elsif (heading = line[/\A\#{3,4} (.+)/, 1])
          finish_para.call
          out << [:heading, heading]
        elsif (item = line[/\A ?\* (.+)/, 1])
          finish_para.call
          out << [:item, item]
        elsif line.strip.empty?
          finish_para.call
        elsif out.last&.first == :item && words.empty? && line.start_with?("  ")
          out.last[1] = "#{out.last[1]} #{line.strip}"
        else
          words << line.strip
        end
      end
      finish_para.call
      out
    end

    def draw_block(kind, text = nil)
      case kind
      when :picture
        path = File.join(File.dirname(FILE), text)
        image path, margin: [18, 4, 18, 12] if File.exist?(path)
      when :colors then color_list
      when :index then class_list
      when :samples then nil # Shoes 3 listed the samples it came with; this manual has none to list
      when :heading
        tagline(*inline(text), size: 15, weight: "bold", stroke: "#7a3310", margin: [18, 14, 18, 4])
      when :code
        stack margin: [18, 4, 18, 10] do
          background "#ece6d6", curve: 4
          para text, family: "monospace", size: 10, stroke: "#2b2b2b", margin: 8
        end
      when :item
        para "•  ", *inline(text), size: 11, margin: [30, 2, 18, 4]
      else
        pieces = inline(text)
        para(*pieces, size: 11, margin: [18, 4, 18, 8]) unless pieces.all? { |p| p.to_s.strip.empty? }
      end
    end

    # Every named colour on a swatch of itself, its name and its numbers under it, three to a row,
    # as Shoes 3's manual drew its Colors List (help.rb color_page).
    def color_list
      flow margin: [18, 4, 18, 12] do
        Shoes::COLORS.keys.sort.each do |name|
          r, g, b = Shoes::COLORS[name]
          dark = (r * 299 + g * 587 + b * 114) / 1000 < 128
          flow width: 0.33 do
            background rgb(r, g, b)
            para strong(name.to_s), "\n", "rgb(#{r}, #{g}, #{b})", size: 9, align: "center",
              stroke: dark ? white : black, margin: 4
          end
        end
      end
    end

    # The classes Shoes brings, each under the class it comes from, as Shoes 3's manual drew its
    # Classes List (help.rb index_page): the drawables and the colour, not the machinery under
    # them. A name with a section of its own links to it.
    def class_list
      classes = Shoes.constants.sort.filter_map do |name|
        klass = Shoes.const_get(name)
        klass if klass.is_a?(Class) && klass.name&.start_with?("Shoes::") && (klass <= Shoes::Drawable || klass.name == "Shoes::Color")
      end
      children = classes.group_by(&:superclass)
      roots = classes.reject { |k| classes.include?(k.superclass) }
      stack margin: [18, 4, 18, 12] do
        roots.sort_by(&:name).each { |k| class_branch(k, children, 0) }
      end
    end

    def class_branch(klass, children, depth)
      para "▸ ", wiki_link(klass.name.delete_prefix("Shoes::")), size: 10, margin: [depth * 20, 1, 0, 1]
      Array(children[klass]).sort_by(&:name).each { |k| class_branch(k, children, depth + 1) }
    end

    def inline(text)
      text.split(INLINE).reject(&:empty?).map do |piece|
        case piece
        when /\A`'(.+)`'\z/m then em(Regexp.last_match(1))
        when /\A`(.+)`\z/m then code(Regexp.last_match(1))
        when /\A__(.+)__\z/m, /\A\*\*(.+)\*\*\z/m then strong(Regexp.last_match(1))
        when /\A!\[/ then "" # blocks draws a picture under the words it closes
        when "[[BR]]" then "\n"
        when /\A\[\[(.+)\]\]\z/ then wiki_link(Regexp.last_match(1))
        else piece
        end
      end
    end

    # [[Element.window]] or [[Element Element Creation]]: a link to the section about it, or
    # its words when no section is.
    def wiki_link(target)
      name, words = target.split(" ", 2)
      label = words || name.split(".").last
      topic = name.split(".").last.downcase
      found = @sections.find do |s|
        s.title.downcase.start_with?(topic) || s.lines.any? { |l| l.downcase.start_with?("### #{topic}") }
      end
      found ? link(label) { turn_to(found) } : label
    end
  end
end
