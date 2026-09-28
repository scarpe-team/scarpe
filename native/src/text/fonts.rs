//! Building the FontSystem: bundled (deterministic) or the host's fonts.

use cosmic_text::{fontdb, Family, FontSystem};
use std::collections::{HashMap, HashSet};
use std::path::Path;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FontMode {
    System,
    Bundled,
}

/// How an app's text is sized and set: Lacci's `Shoes.text_mode`, sent as `text_mode` (ledger
/// M14, DESIGN 4.1).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum TextMode {
    /// Scarpe's own: a size is pixels, and text is set in the system's sans.
    #[default]
    Scarpe,
    /// Shoes 3's: a size is points at 96 dpi, so a para's 12 is 16 px (s3t_textblock.c:293),
    /// and a text block names Arial when it names no face (s3_world.c:46-48), for programs laid
    /// out for Shoes 3, such as Hackety Hack.
    Shoes3,
}

impl TextMode {
    pub fn parse(name: &str) -> Option<TextMode> {
        match name.trim_start_matches(':') {
            "scarpe" => Some(TextMode::Scarpe),
            "shoes3" => Some(TextMode::Shoes3),
            _ => None,
        }
    }

    /// A size as the app wrote it, in pixels.
    pub fn px(self, size: f32) -> f32 {
        match self {
            TextMode::Scarpe => size,
            TextMode::Shoes3 => size * 96.0 / 72.0,
        }
    }
}

const INTER: &[u8] = include_bytes!("../../assets/fonts/InterVariable.ttf");
const INTER_ITALIC: &[u8] = include_bytes!("../../assets/fonts/InterVariable-Italic.ttf");
const FIRA_MONO: &[u8] = include_bytes!("../../assets/fonts/FiraMono-Medium.ttf");

const BUNDLED_SANS: &str = "Inter Variable";
const BUNDLED_MONO: &str = "Fira Mono";

const SANS: &[&str] = &["System Font", "Helvetica Neue", "Segoe UI", "Noto Sans", "DejaVu Sans", "Arial", BUNDLED_SANS];
const SERIF: &[&str] = &["Times New Roman", "Times", "Georgia", "Noto Serif", "DejaVu Serif", "Liberation Serif"];
const MONO: &[&str] = &["Menlo", "SF Mono", "Consolas", "DejaVu Sans Mono", "Liberation Mono", BUNDLED_MONO];

/// Font families available to text, with the generic families resolved.
pub struct Fonts {
    pub system: FontSystem,
    families: HashSet<String>,
    /// `font "fonts/Pacifico.ttf"` makes "Pacifico" usable even if the file's
    /// internal family name differs (Lacci adds the file's basename to Shoes::FONTS).
    aliases: HashMap<String, String>,
    pub sans: String,
    pub serif: String,
    pub mono: String,
    pub text_mode: TextMode,
}

impl Fonts {
    pub fn new(mode: FontMode) -> Self {
        let mut system = match mode {
            FontMode::Bundled => {
                let db = fontdb::Database::new();
                FontSystem::new_with_locale_and_db("en-US".into(), db)
            }
            FontMode::System => FontSystem::new(),
        };
        let db = system.db_mut();
        db.load_font_data(INTER.to_vec());
        db.load_font_data(INTER_ITALIC.to_vec());
        db.load_font_data(FIRA_MONO.to_vec());
        let mut fonts = Fonts {
            system,
            families: HashSet::new(),
            aliases: HashMap::new(),
            sans: BUNDLED_SANS.into(),
            serif: BUNDLED_SANS.into(),
            mono: BUNDLED_MONO.into(),
            text_mode: TextMode::Scarpe,
        };
        fonts.refresh_families();
        if mode == FontMode::System {
            fonts.sans = fonts.first_present(SANS).unwrap_or(BUNDLED_SANS).to_string();
            fonts.serif = fonts.first_present(SERIF).unwrap_or(&fonts.sans.clone()).to_string();
            fonts.mono = fonts.first_present(MONO).unwrap_or(BUNDLED_MONO).to_string();
        }
        let (sans, serif, mono) = (fonts.sans.clone(), fonts.serif.clone(), fonts.mono.clone());
        let db = fonts.system.db_mut();
        db.set_sans_serif_family(sans);
        db.set_serif_family(serif);
        db.set_monospace_family(mono);
        fonts
    }

    fn refresh_families(&mut self) {
        self.families = self
            .system
            .db()
            .faces()
            .flat_map(|f| f.families.iter().map(|(name, _)| name.to_lowercase()))
            .collect();
    }

    fn first_present<'a>(&self, candidates: &[&'a str]) -> Option<&'a str> {
        candidates.iter().copied().find(|c| self.families.contains(&c.to_lowercase()))
    }

    /// Registers a font file (the `font` builtin). Returns the new family names.
    pub fn register(&mut self, path: &Path) -> Vec<String> {
        if !crate::limits::readable_file(path, crate::limits::MAX_FONT_BYTES) {
            return Vec::new();
        }
        let before: HashSet<fontdb::ID> = self.system.db().faces().map(|f| f.id).collect();
        if self.system.db_mut().load_font_file(path).is_err() {
            return Vec::new();
        }
        let added: Vec<String> = self
            .system
            .db()
            .faces()
            .filter(|f| !before.contains(&f.id))
            .filter_map(|f| f.families.first().map(|(n, _)| n.clone()))
            .collect();
        if let (Some(stem), Some(first)) = (path.file_stem().and_then(|s| s.to_str()), added.first()) {
            self.aliases.insert(stem.to_lowercase(), first.clone());
        }
        self.refresh_families();
        added
    }

    /// The face a text block that names none is set in: Shoes 3's Arial in its text mode, when
    /// the machine has it; the sans otherwise.
    pub fn text_face(&self) -> FamilyName {
        match self.text_mode {
            TextMode::Shoes3 if self.families.contains("arial") => FamilyName::Named("Arial".into()),
            _ => FamilyName::Sans,
        }
    }

    /// Maps a Shoes family string (maybe a comma list, maybe a generic name) to a
    /// family cosmic-text can match. Unknown families fall back to sans.
    pub fn resolve_family(&self, requested: &str) -> FamilyName {
        for candidate in requested.split(',').map(|c| c.trim().trim_matches(|c| c == '"' || c == '\'' || c == ';').trim()) {
            if candidate.is_empty() {
                continue;
            }
            let lower = candidate.to_lowercase();
            match lower.as_str() {
                "sans" | "sans-serif" | "sans serif" | "arial" if !self.families.contains(&lower) => return FamilyName::Sans,
                "serif" => return FamilyName::Serif,
                "mono" | "monospace" | "courier" | "courier new" if !self.families.contains(&lower) => return FamilyName::Mono,
                _ => {}
            }
            if let Some(real) = self.aliases.get(&lower) {
                return FamilyName::Named(real.clone());
            }
            if self.families.contains(&lower) {
                return FamilyName::Named(candidate.to_string());
            }
        }
        FamilyName::Sans
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum FamilyName {
    Sans,
    Serif,
    Mono,
    Named(String),
}

impl FamilyName {
    pub fn as_family(&self) -> Family<'_> {
        match self {
            FamilyName::Sans => Family::SansSerif,
            FamilyName::Serif => Family::Serif,
            FamilyName::Mono => Family::Monospace,
            FamilyName::Named(name) => Family::Name(name),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn registered_fonts_answer_to_their_file_name() {
        let mut fonts = Fonts::new(FontMode::Bundled);
        let added = fonts.register(Path::new("assets/fonts/FiraMono-Medium.ttf"));
        assert_eq!(added, vec!["Fira Mono".to_string()]);
        assert_eq!(fonts.resolve_family("FiraMono-Medium"), FamilyName::Named("Fira Mono".into()));
        assert_eq!(fonts.resolve_family("Fira Mono"), FamilyName::Named("Fira Mono".into()));
        assert_eq!(fonts.resolve_family("No Such Font, monospace"), FamilyName::Mono);
        assert_eq!(fonts.resolve_family("serif"), FamilyName::Serif);
        assert_eq!(fonts.resolve_family("Nope"), FamilyName::Sans);
    }
}
