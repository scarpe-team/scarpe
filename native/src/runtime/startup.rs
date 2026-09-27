//! Loading the system fonts off the main thread. The font database takes 30 ms warm and about
//! 200 ms cold to load (native/PERF.md); window.rs starts it before the event loop, so it loads
//! while the loop starts, the handshake runs and the window opens. The Runtime starts with the
//! bundled fonts as a stand-in and swaps the system ones in before anything is laid out.

use super::Runtime;
use crate::protocol::Outbox;
use crate::runtime::Options;
use crate::text::{FontMode, Fonts, TextEngine};
use std::thread::JoinHandle;
use std::time::Instant;

/// System fonts on their way, and when they finished loading.
pub type FontsLoading = JoinHandle<(Fonts, Instant)>;

/// Starts loading the fonts for `mode` on a thread of their own.
pub fn load_fonts(mode: FontMode) -> FontsLoading {
    std::thread::spawn(move || (Fonts::new(mode), Instant::now()))
}

impl Runtime {
    /// A Runtime whose fonts are still loading (`load_fonts`).
    pub fn with_fonts_loading(opts: Options, out: Outbox, loading: FontsLoading) -> Self {
        let mut rt = Runtime::new(Options { fonts: FontMode::Bundled, ..opts.clone() }, out);
        rt.opts = opts;
        rt.fonts_loading = Some(loading);
        rt
    }

    /// Swaps in the fonts that were loading, waiting for them if they are not there yet.
    pub(super) fn fonts_ready(&mut self) {
        let Some(loading) = self.fonts_loading.take() else { return };
        let Ok((fonts, loaded_at)) = loading.join() else {
            eprintln!("[scarpe-native] loading the system fonts failed; drawing with the bundled ones");
            return;
        };
        if self.text.cached_shapes() > 0 || !self.text.raster.is_empty() {
            // Something was shaped with the stand-in fonts: no cached shape or glyph may survive.
            self.text = TextEngine::new(FontMode::Bundled);
        }
        self.text.fonts = fonts;
        self.stats.mark_at("system_fonts_loaded", loaded_at);
        self.stats.mark("system_fonts_ready");
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::runtime::Options;

    #[test]
    fn fonts_loaded_elsewhere_arrive_before_the_first_layout() {
        let opts = Options { headless: true, scale: Some(1.0), fonts: FontMode::Bundled, trace: false };
        let mut rt = Runtime::with_fonts_loading(opts, Outbox::capture(), load_fonts(FontMode::Bundled));
        for line in [
            r#"{"t":"create","id":2,"kind":"DocumentRoot","parent":null,"props":{}}"#,
            r#"{"t":"create","id":1,"kind":"App","parent":null,"props":{"width":200,"height":100},"doc_root":2}"#,
            r#"{"t":"create","id":3,"kind":"Para","parent":2,"props":{"text_items":["Hello"]}}"#,
            r#"{"t":"run","app":1}"#,
        ] {
            rt.handle_line(line);
        }
        assert!(rt.fonts_loading.is_some(), "nothing has needed a font yet");
        rt.handle_line(r#"{"t":"flush"}"#);
        assert!(rt.fonts_loading.is_none(), "the first layout waited for them");
        assert!(rt.layout_of(1).is_some_and(|l| l.texts.contains_key(&3)));
    }

    #[test]
    fn text_shaped_with_the_stand_in_fonts_is_forgotten() {
        let opts = Options { headless: true, scale: Some(1.0), fonts: FontMode::Bundled, trace: false };
        let mut rt = Runtime::with_fonts_loading(opts, Outbox::capture(), load_fonts(FontMode::Bundled));
        let rich = crate::text::RichText::plain("early", crate::text::TextStyle::new(12.0, crate::style::Color::BLACK));
        rt.text.shape(&rich, None);
        assert_eq!(rt.text.cached_shapes(), 1);
        rt.fonts_ready();
        assert_eq!(rt.text.cached_shapes(), 0);
    }
}
