---
layout: default
title: Scarpe Features
---

# Extending _why's Legacy

![Would _why have a beard if he existed now](image.png)

The leading mission for Scarpe has been to implement as much backwards compatibility as possible for _why's original
Shoes library. This remains true. _why's taste and DSL are celebrated and preserved. However, at the discretion of
core maintainers, new features may be added. They must be approved by Noah Gibbs or Nick Schwaderer, and described
in this file. They cannot conflict or damage backwards compatibility with the original Shoes library.

## Page Navigation

Similar to URL navigation. see `url_navigation_single_app.rb` for an example. Unlike URLs, they do not accept parameters,
only the name of the page. They are simply declared and named in blocks.

```ruby
Shoes.app do
  page(:home) do
    title "Home Page"
    para "Welcome to the home page"
    button "Go to another page" do
      visit(:another_page)
    end
  end

  page(:another_page) do
    title "Another Page"
    para "Welcome to another page"
    button "Go to home page" do
      visit(:home)
    end
  end
end
```

## Running a program in a process of its own

`Shoes.run_program(path, dir:, args:)` starts another Shoes program in a process of its own, on
the same Ruby and Scarpe, and returns a `Shoes::Program`: `pid`, `running?`, `stop`, and blocks for
its output, its errors and its end. A program that never stops freezes only itself. Approved by
Nick Schwaderer on 28 Sep 2026, for Hackety Hack's Run button, which in Shoes 3 evaluated a
child's program inside Hackety Hack. On the native display only; the others run the program
inside the app, as Shoes 3 did, with a warning. `docs/native.md` shows it in use, and
`native/DESIGN.md` 5.5 has the protocol.

```ruby
Shoes.app do
  button "Run" do
    @game = Shoes.run_program("game.rb")
    @game.on_error { |err| alert "#{err["message"]} (line #{err["line"]})" }
  end
  button("Stop") { @game&.stop }
end
```

## `Shoes.on_error`

`Shoes.on_error { |err| }` hears every error a handler, a timer or the program's startup raises,
as a Hash with String keys (`class`, `message`, `backtrace`, `path`, `line`, `during`), besides
the log line and the Shoes console's entry. The program goes on as before. Approved by Nick
Schwaderer on 28 Sep 2026, so an app can show its own errors in its own words; Shoes 3 only put
them in its console.
