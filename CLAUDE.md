# Scarpe - AI Assistant Context

> *In loving memory of Noah Gibbs, who believed in this project and whose thoughtful documentation lives on in every design decision.*

## What is Scarpe?

**Scarpe** (Italian for "shoes") is a modern reimplementation of [Why The Lucky Stiff's Shoes](https://github.com/shoes/shoes-deprecated) - a beloved Ruby GUI toolkit that made desktop app creation accessible to absolute beginners.

```ruby
# This is all it takes to create a window with a button
Shoes.app { button("Click me!") { alert("Good job.") } }
```

Scarpe preserves _why's elegant DSL while building on modern technology (Webview). It is **not yet complete**, but actively maintained.

## The Mission

Our primary goal is **backwards compatibility with classic Shoes apps**. We want old Shoes programs to just work.

### The Bible

`docs/static/manual.md` (3,500+ lines) is our authoritative reference for how Shoes _should_ work. Every implementation decision should align with this manual.

### The Proving Ground

`examples/legacy/not_checked/` contains Shoes apps that **used to work** in classic Shoes. Getting these examples running is our north star.

## Architecture Overview

Scarpe has a layered architecture:

### Lacci (The Compatibility Layer)
**Location:** `lacci/`

Lacci (Italian for "laces") translates Shoes commands into display-agnostic operations:
- Implements the Shoes4 drawing model (stacks, flows, slots)
- Handles margin calculations, fonts, layout
- Uses **Niente** (null display service) for testing

See: `docs/lacci.md`

### Display Service (The Renderer)
**Location:** `lib/scarpe/`

The display service runs as a **separate process** from the main application:
- Clear separation between app logic and display logic
- Different display implementations can be swapped
- Communication via well-defined message protocol
- Supports local and relay-based services

See: `docs/display_service_separation.md`

### Calzini (The Components)
Components follow a lifecycle pattern with state management and event handling.

See: `docs/calzini_components_and_updates.md`

## Key Documentation

All in `docs/`:

| Document | Purpose |
|----------|---------|
| `static/manual.md` | **THE BIBLE** - How Shoes should work |
| `lacci.md` | Compatibility layer documentation |
| `display_service_separation.md` | Architecture decisions |
| `shoes_and_display_events.md` | Event handling details |
| `event_loops.md` | Event loop architecture |
| `timeouts_and_handlers.md` | Timing and callbacks |
| `calzini_components_and_updates.md` | Component system |
| `scarpe_shoes_incompatibilities.md` | Known differences from Shoes |
| `shoes_implementations.md` | History of Shoes implementations |
| `SCARPE_FEATURES.md` | New features beyond original Shoes |
| `yard/catscradle.md` | Fiber-based testing approach |

## Running Scarpe

```bash
# Install dependencies (Linux only - Mac works out of the box)
sudo apt install libgtk-3-dev libwebkit2gtk-4.0-dev  # Ubuntu/Debian

# Install gems
bundle install

# Run an example
./exe/scarpe examples/button.rb --dev --debug

# With a theme
SCARPE_BOOTSTRAP_THEME=sketchy bundle exec ./exe/scarpe examples/button.rb --debug

# Optional: For sound support (bloopsaphone examples)
# gem install bloops  # requires portaudio: brew install portaudio (Mac)
```

## Testing

```bash
# Run all tests
bundle exec rake ci_test

# Run component tests
bundle exec rake lacci_test      # Lacci tests
bundle exec rake component_test  # Scarpe-components tests
bundle exec rake test           # Scarpe tests

# Check HTML output
bundle exec rake test:check_html_fixtures
```

### Testing Philosophy

- Test new features with **Niente** (null display) first
- Use **Fiber-based testing** for complex event interactions (see CatsCradle)
- Keep handlers non-blocking
- Maintain backward compatibility

## Development Workflow

### When Debugging Failed Tests

1. Add strategic `puts` statements to understand the issue
2. Run the test and analyze output
3. Implement the fix
4. Verify the fix
5. **Remove all debugging statements before committing**

### Commit Style

```
Add request validation to UserWidget

Prevents invalid requests from reaching the database layer.
Adds type checking and parameter validation before processing.

Impact: Improved error handling and reduced DB load.
```

- First line: Clear statement of WHAT (50 chars ideal)
- Empty line after header
- Body: WHY needed, HOW it works, technical implications

## Code Patterns

### Display Service Singleton
```ruby
class DisplayService < Shoes::DisplayService
  class << self
    attr_accessor :instance
  end

  def initialize
    if DisplayService.instance
      raise Shoes::Errors::SingletonError, "This is meant to be a singleton!"
    end
    DisplayService.instance = self
  end
end
```

### Event Dispatch
```ruby
def dispatch_event(event_name, event_target, *args, **kwargs)
  handlers = [
    same_name_handlers[:any],
    same_name_handlers[event_target],
    any_name_handlers[:any],
    any_name_handlers[event_target],
  ].compact.inject([], &:+)
  handlers.each { |h| h[:handler].call(*args, **kwargs) }
end
```

## Core Values

From the README:
- **Resiliency** - Tested and trustworthy
- **User Experience** - Beautiful, easy DSL
- **Whimsy** - We're here to have fun! Chunky Bacon. 🥓
- **Empathy** - Help one another

## Adding New Features

New features beyond original Shoes require approval and must:
1. Not conflict with backwards compatibility
2. Be documented in `docs/SCARPE_FEATURES.md`
3. Follow existing patterns

Example: Page navigation (`page(:home)`, `visit(:another_page)`)

## Project Structure

```
scarpe/
├── lacci/           # Shoes4 compatibility layer
├── lib/scarpe/      # Display service implementations
├── scarpe-components/  # Shared components
├── examples/        # Example apps
│   └── legacy/not_checked/  # Apps to fix!
├── docs/            # Design documentation
│   └── static/manual.md    # THE BIBLE
├── test/            # Test suite
└── exe/scarpe       # Main executable
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `SCARPE_DISPLAY_SERVICE` | Choose display service (wv_local, wv_relay, etc.) |
| `SCARPE_TEST_CONTROL` | Path to test control script |
| `SCARPE_LOG_CONFIG` | YAML file for component log levels |
| `SCARPE_BOOTSTRAP_THEME` | UI theme (e.g., "sketchy") |

## Links

- [GitHub Repository](https://github.com/scarpe-team/scarpe)
- [Wiki](https://github.com/scarpe-team/scarpe/wiki)
- [Discord](https://discord.gg/Ca5EHSsGYp)
- [Nobody Knows Shoes - _why's Manual](https://github.com/whymirror/why-archive/raw/master/shoes/nobody-knows-shoes.pdf)

---

*Scarpe Diem: Seize the Shoes*
