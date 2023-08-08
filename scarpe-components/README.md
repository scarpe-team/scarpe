# Scarpe-Components

Scarpe is several things. We package up the Shoes API with as few implementation details as possible (called Lacci.) We have a Webview-based display library, in both local and over-a-socket (relay) versions. We have a Wasm display library (Scarpe-Wasm) in a separate gem.

And we have various default implementations of different reusable components. Scarpe's hierarchical logger isn't particularly specific to your display library or underlying GUI library, but we'd like it to be usable by multiple display libs. CatsCradle is only useful if you're trying to fix up an impedance mismatch between Ruby and an evented under-layer, but it's not really specific to Webview. Scarpe's default downloader, using Ruby's built-in HTTP libraries, is good in many cases but you might want to replace it (e.g. with Typhoeus for better parallel downloads or Hystrix for robustness to bad network connections) in some cases.

Part of our solution is the Scarpe-Components gem, which lives in the same repository as Scarpe (for now?). These components can live there. Any specific display library can pick and choose what it wants or needs and handle its dependencies as it sees fit.

## Dependency Hell

A "gem full of optional reusable components" presents an awkward challenge for Rubygems. What are the gem's dependencies? Do you make it depend on every possible library, requiring FastImage and Nokogiri and SQLite and whatever else any component might ever require? That would be as bad as making ActiveRecord need MySQL and SQLite and Postgres and Oracle and... But if you don't give it *any* dependencies, you're going to have a harsh surprise at runtime when Bundler can't find any of the gems you need.

You can break everything up into tiny pieces, like ActiveRecord having a separate adapter for certain databases. You could do the same with an activerecord-mysql and activerecord-postgres and activerecord-sqlite gem to complete the set. Or, like, ActiveRecord, you can say "declare activerecord as a dependency, and also one or more other database gems, and we'll figure out what's available at runtime." That approach can be pretty fragile and it adds extra complexity -- how do you make sure everything is required at the right time and ActiveRecord can find everything that's available? How do you balance gem dependencies that are built into ActiveRecord with those for unusual databases that get added by other gems, later? Your plugin system (like ActiveRecord's) can get extensive and fragile.

Scarpe-Components kicks that problem down the road to the display libraries. Would a particular display library like to use the FastImage-based image implementation? Great! It can declare a dependency on the FastImage gem. Would it like to optionally allow the built-in Ruby downloader, but also have an optional robustified version using RestClient? Lovely. It can either create multiple gems (e.g. scarpe-gtk-rcdownload and scarpe-gtk-plaindownload) or look for RestClient being available at runtime, as it pleases. The FastImage implementation lives in Scarpe-Components, but the dependency is declared by the display library or the app.

## Using an Implementation

Components in Scarpe-Components are designed to be used individually. They can require each other, but they should only require components they will actually use. The whole library is designed to be used a la carte, and normally no display service will use every component.

A display library will declare scarpe-components as a dependency. Then, usually from its named require file (e.g. wv_local.rb, wv_relay.rb, wasm_local.rb) it will set up those dependencies by requiring components that it wants and if necessary creating and configuring them. That way a specific display service (e.g. wv_local) can require a specific component (e.g. Logging-gem-based hierarchical logging) and configure it how it wants (e.g. ENV var pointing to a local JSON config file.)

## How is this Different from Lacci?

Scarpe already has a gem full of reusable components, one that every Scarpe-based application already has to use. Lacci declares the Shoes API, and is 100% required for every Scarpe-based Shoes application everywhere.

So how do you tell what goes into Scarpe-Components vs what goes into Lacci?

Lacci is, at heart, an API with as little implementation as possible. It declares the Shoes GUI objects, but not how to display them. Ordinarily a Shoes application will require (in the sense of Kernel#require) every part of Lacci -- it will load the entire library. Even if we add optional components (e.g. a Lacci-based Bloops API with no implementation behind it), those components will be loaded by every Shoes app that uses that part of the API.

As a result, Lacci should have minimal (preferably zero) dependencies. Any code doing "real work" should be removed from Lacci completely, as soon as possible. Since *every* Shoes app is going to require Lacci, it should be possible to use it with essentially no dependencies, minimal memory footprint, minimal load time. It is a skeleton to hang functionality on, not a thing that functions for itself.

Scarpe-Components is a grab bag of default implementations, intended to be replaceable. But each of them does something. Most of them have dependencies. It's fine for a Scarpe-Component implementation to depend on the Logging gem, provided it says it does. Nokogiri? 100% fair. Does it do something with a nontrivial amount of computation, like rendering HTML output? No problem. This is very different from Lacci.

If a component should be reused, it's probably fine to put it into Scarpe-Components. It *might* be fine to put it in Lacci. For Scarpe-Components, ask yourself, "will more than one Scarpe display service possibly want to use this?" For Lacci, the test is more strict: "will *every* Scarpe display service want to use this? Does it have no dependencies at all, and do very little computation and take very little memory?"
