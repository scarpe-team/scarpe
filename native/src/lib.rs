//! scarpe-native: a native display service for Scarpe, the Ruby Shoes.
//!
//! Ruby (Lacci + a thin shim) thinks; this process draws. They talk NDJSON
//! over stdin/stdout (DESIGN.md section 4). Dedicated to Noah Gibbs, who made
//! Scarpe's display services swappable.

pub mod a11y;
pub mod automation;
pub mod dialogs;
pub mod doc;
pub mod elements;
pub mod headless;
pub mod input;
pub mod layout;
pub mod limits;
pub mod paint;
pub mod props;
pub mod protocol;
pub mod runtime;
pub mod style;
pub mod text;
pub mod window;

pub use runtime::{Options, Runtime};
