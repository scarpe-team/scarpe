## [Unreleased Future]

Here we write upgrading notes for brands. It's a team effort to make them as
straightforward as possible.

### Enhancements

### Bugs Fixed
- #-some-pr-number <description> @author-of-pr

### Incompatibilities

## [0.3.1] - 2023-??-?? - Up

Lots of bug fixes. We're also still implementing major Shoes3 features.
Testing is finally improving at a reasonable rate, but we have a long
way to go.

The Scarpe architecture is still early. We've improved the internal APIs
for creating drawables significantly, added an asset server and are
still making big changes.

### Enhancements

- Ovals!
- Features! Shoes.app(feature: [:html, :scarpe]) lets apps declare dependencies on non-classic Shoes!
- The html_class style is a feature to make it easier to do Bootstrap styling on your drawables
- Directly run Shoes Specs, including with Niente
- We use Minitest assertion DSL rather than our own everywhere now
- Better handling of :left, :top, :width and :height, :margin and :padding on more drawables

### Bugs Fixed

- We've changed "module Shoes" to "class Shoes" for Shoes3 compatibility.
- Several style and method names, including on Para and ListBox, changed to Shoes3 standard.

### Incompatibilities

We're deprecating the CatsCradle test DSL in favour of Shoes-Spec.
Some error names have changed, with more to come.
We've changed the Lacci drawable-create event to include the parent ID.

## [0.3.0] - 2023-11-24 - You

- Progress bars
- Various new APIs and many bug fixes
- Added Tiranti, a Bootstrap-based Calzini HTML renderer replacement
- Added Calzini, a Drawable-to-HTML renderer
- Rename of Widget to Drawable
- Extremely early Shoes-Spec testing support
- Niente, a "no-op" testing display service

## [0.2.1] - 2023-07-02 - Give

- Bugfix release

## [0.2.0] - 2023-07-02 - Gonna

- First batch of functionality. Will aggressively track to changelog from here on out.

## [0.1.0] - 2023-02-09 - Never

- Initial release
