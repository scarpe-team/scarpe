//! Widgets: one file each. Every widget knows its intrinsic size and how to
//! paint itself; pointer and key behaviour that belongs to one widget lives in
//! its file too, and input.rs does the routing.

pub mod button;
pub mod check;
pub mod edit_box;
pub mod edit_line;
pub mod image;
pub mod list_box;
pub mod progress;
pub mod radio;
pub mod slider;
pub mod text_field;
pub mod tooltip;
pub mod video;

use crate::doc::{Kind, Node};
use crate::input::ViewState;
use crate::layout::{LBox, Rect, TextBox};
use crate::paint::Canvas;
use crate::style::Color;
use crate::text::{ShapedText, TextEngine};
use image::ImageCache;

pub const ACCENT: Color = Color::rgb(0x0a, 0x84, 0xff);
pub const FIELD_BORDER: Color = Color::rgb(0xc7, 0xc7, 0xcc);
pub const CONTROL_TEXT_SIZE: f32 = 13.0;
pub const FOCUS_RING: Color = Color::rgba(0x0a, 0x84, 0xff, 80);

/// A text label placed inside a widget's box.
pub struct Label {
    pub shaped: ShapedText,
    pub dx: f32,
    pub dy: f32,
}

/// How a widget looks right now.
#[derive(Clone, Copy, Debug, Default)]
pub struct WidgetState {
    pub hovered: bool,
    pub pressed: bool,
    pub focused: bool,
}

pub fn intrinsic_size(node: &Node, text: &mut TextEngine, images: &mut ImageCache) -> (f32, f32) {
    match node.kind {
        Kind::Button => button::size(node, text),
        Kind::Check | Kind::Radio => (18.0, 18.0),
        Kind::EditLine => (200.0, 28.0),
        Kind::EditBox => (200.0, 108.0),
        // The manual's sizes (ledger C4): list_box "about 200 pixels wide", progress "200 pixels wide".
        Kind::ListBox => (200.0, 28.0),
        Kind::Progress => (200.0, 14.0),
        Kind::Slider => (160.0, 20.0),
        Kind::Image => image::natural_size(node, images),
        Kind::Video => (300.0, 150.0),
        _ => (0.0, 0.0),
    }
}

pub fn label(node: &Node, w: f32, h: f32, text: &mut TextEngine) -> Option<Label> {
    match node.kind {
        Kind::Button => Some(button::label(node, w, h, text)),
        Kind::ListBox => list_box::label(node, w, h, text),
        _ => None,
    }
}

/// `state: "disabled"` (manual): greyed out, ignores the pointer and keys.
pub fn disabled(node: &Node) -> bool {
    node.props.str("state") == Some("disabled")
}

/// `state: "readonly"`: focusable and selectable, but not editable.
pub fn readonly(node: &Node) -> bool {
    node.props.str("state") == Some("readonly")
}

/// Text fields always show focus; other controls only when it came from the keyboard.
pub fn state_of(node: &Node, view: &ViewState) -> WidgetState {
    let focused = view.focus == Some(node.id) && (node.kind.is_text_input() || view.focus_visible);
    WidgetState {
        hovered: view.hover_chain.contains(&node.id),
        pressed: view.pressed.as_ref().is_some_and(|p| p.target == node.id) && view.hover_chain.contains(&node.id),
        focused,
    }
}

pub fn paint(
    canvas: &mut Canvas,
    node: &Node,
    lbox: &LBox,
    label: Option<&TextBox>,
    view: &mut ViewState,
    text: &mut TextEngine,
    images: &mut ImageCache,
) {
    let state = state_of(node, view);
    match node.kind {
        Kind::Button => button::paint(canvas, node, lbox, label, state, text, images),
        Kind::Check => check::paint(canvas, node, lbox, state),
        Kind::Radio => radio::paint(canvas, node, lbox, state),
        Kind::EditLine => edit_line::paint(canvas, node, lbox, state, view, text),
        Kind::EditBox => edit_box::paint(canvas, node, lbox, state, view, text),
        Kind::ListBox => list_box::paint(canvas, node, lbox, label, state, text),
        Kind::Progress => progress::paint(canvas, node, lbox),
        Kind::Slider => slider::paint(canvas, node, lbox, state),
        Kind::Image => image::paint(canvas, node, lbox, images),
        Kind::Video => video::paint(canvas, lbox),
        _ => {}
    }
    if disabled(node) {
        let r = lbox.rect;
        canvas.fill_rect(Rect::new(r.x - 4.0, r.y - 4.0, r.w + 8.0, r.h + 8.0), Color::rgba(255, 255, 255, 140), lbox.clip);
    }
}

/// The soft focus halo drawn outside a focused control.
pub fn focus_ring(canvas: &mut Canvas, rect: Rect, radius: f32, clip: Option<Rect>) {
    focus_ring_in(canvas, rect, radius, ACCENT, clip);
}

/// The focus halo in a colour of the control's own (a field whose text has one, ledger G17), as
/// light as the default blue one.
pub fn focus_ring_in(canvas: &mut Canvas, rect: Rect, radius: f32, color: Color, clip: Option<Rect>) {
    let halo = Rect::new(rect.x - 3.0, rect.y - 3.0, rect.w + 6.0, rect.h + 6.0);
    canvas.fill_rounded(halo, radius + 3.0, color.with_alpha(FOCUS_RING.a), clip);
}

/// Picks readable text for a coloured surface.
pub fn text_on(surface: Color) -> Color {
    if surface.luminance() < 0.55 {
        Color::WHITE
    } else {
        crate::text::rich::INK
    }
}
