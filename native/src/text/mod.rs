//! Text: fonts, rich text resolution, shaping cache and glyph rasterising.

pub mod fonts;
pub mod raster;
pub mod rich;
pub mod shape_cache;

pub use fonts::{FamilyName, FontMode, Fonts, TextMode};
pub use rich::{RichText, TextStyle};
pub use shape_cache::{ShapedText, SpanMeta};

use raster::GlyphRaster;
use shape_cache::ShapeCache;

pub struct TextEngine {
    pub fonts: Fonts,
    pub raster: GlyphRaster,
    shapes: ShapeCache,
}

impl TextEngine {
    pub fn new(mode: FontMode) -> Self {
        TextEngine { fonts: Fonts::new(mode), raster: GlyphRaster::default(), shapes: ShapeCache::default() }
    }

    pub fn shape(&mut self, rich: &RichText, width: Option<f32>) -> ShapedText {
        self.shape_indented(rich, width, 0.0)
    }

    /// Shapes text whose first line starts `indent` px in, where it continues a line.
    pub fn shape_indented(&mut self, rich: &RichText, width: Option<f32>, indent: f32) -> ShapedText {
        let tracking = self.fonts.sans == "System Font";
        self.shapes.get(&mut self.fonts.system, rich, width, indent, tracking)
    }

    /// The width text wants when nothing constrains it.
    pub fn max_content(&mut self, rich: &RichText) -> f32 {
        self.shape(rich, None).width.ceil()
    }

    /// A layout of the app whose document root is `owner` begins; end_layout ends it.
    pub fn begin_layout(&mut self, owner: crate::props::Id) {
        self.shapes.begin_layout(owner);
    }

    pub fn end_layout(&mut self) {
        self.shapes.sweep();
        self.raster.trim();
    }

    /// The app whose document root is `owner` closed.
    pub fn forget_layout(&mut self, owner: crate::props::Id) {
        self.shapes.forget_layout(owner);
    }

    pub fn cached_shapes(&self) -> usize {
        self.shapes.len()
    }

    /// How many texts have been shaped so far: what the cache could not answer.
    pub fn texts_shaped(&self) -> u64 {
        self.shapes.shaped()
    }
}
