//! Art geometry (rect oval line arrow star arc shape) and how it is painted.
//!
//! Geometry follows Shoes 3 (`shoes/types/shape.c`) except where the manual
//! rules otherwise (research 06): arrows and stars are centred on (left, top),
//! an arc sits in its (left, top, width, height) box like an oval.

use super::{with_shader, Canvas};
use crate::doc::{Doc, Kind, Node};
use crate::elements::image::ImageCache;
use crate::layout::{LBox, Rect};
use crate::props::{Id, Props};
use crate::style::{Color, Paint};
use serde_json::Value;
use std::collections::HashMap;
use std::f32::consts::{FRAC_PI_2, PI, TAU};
use tiny_skia::{FillRule, LineCap, LineJoin, Path, PathBuilder, Stroke, Transform};

pub struct Art {
    /// The shape's own box before the draw context's transforms: gradients stretch
    /// across it and rotate/scale turn about its corner (or centre).
    pub frame: Rect,
    /// Where it shows once transformed: its layout box, for hit-testing and culling.
    pub bounds: Rect,
    pub path: Path,
    pub transform: Transform,
    /// Lines have no inside to fill.
    pub fillable: bool,
}

/// The geometry of an art element positioned against `origin`, its slot's
/// content origin. `parent` is the slot's content size, for relative values.
/// The draw context's `translate` moves it; `rotate`, `scale` and `skew` turn it.
pub fn art(node: &Node, origin: (f32, f32), parent: (f32, f32)) -> Option<Art> {
    let (tx, ty) = translation(&node.props);
    let origin = (origin.0 + tx, origin.1 + ty);
    let (frame, path, fillable) = geometry(node, origin, parent)?;
    let (frame, path) = hug_far_edges(node, origin, parent, frame, path)?;
    let transform = art_transform(node, frame);
    Some(Art { bounds: transformed_box(frame, transform), frame, path, transform, fillable })
}

/// Where `right:` and `bottom:` put an art element's far edges: that far in from the slot's
/// own right and bottom edges, as for every element (manual 1100-1106, 1356-1364, ledger C10).
fn far_edges(p: &Props, origin: (f32, f32), parent: (f32, f32)) -> (Option<f32>, Option<f32>) {
    let dim = |key: &str, basis: f32| p.dim(key).map(|d| d.resolve(basis));
    (dim("right", parent.0).map(|r| origin.0 + parent.0 - r), dim("bottom", parent.1).map(|b| origin.1 + parent.1 - b))
}

/// Art with a far edge but no near one sits against the far edge; `left` and `top` win
/// when both are given (DESIGN 6).
fn hug_far_edges(node: &Node, origin: (f32, f32), parent: (f32, f32), frame: Rect, path: Path) -> Option<(Rect, Path)> {
    let p = &node.props;
    let (right, bottom) = far_edges(p, origin, parent);
    let dx = right.filter(|_| !p.has("left")).map_or(0.0, |r| r - frame.right());
    let dy = bottom.filter(|_| !p.has("top")).map_or(0.0, |b| b - frame.bottom());
    if dx == 0.0 && dy == 0.0 {
        return Some((frame, path));
    }
    Some((frame.translate(dx, dy), path.transform(Transform::from_translate(dx, dy))?))
}

/// A coordinate of an art element (`left`, `top`, a line's `x2` and `y2`), from its slot's
/// content origin. Any number is a plain coordinate: the manual draws shapes "at pixel
/// coordinates" and Shoes 3 reads art in whole pixels (shoes_place_exact, s3_ruby.c:385-392;
/// ledger C15). So art moves off the left and top edges, and a Float between 0 and 1 sits a
/// hair from the edge rather than across the slot, which art animated through the corner
/// passes on its way. Only a percentage is of the slot.
fn coordinate(p: &Props, key: &str, basis: f32) -> Option<f32> {
    p.get(key).and_then(crate::style::dim::parse_number).or_else(|| p.dim(key).map(|d| d.resolve(basis)))
}

/// A size of an art element (`width`, `height`): a number of pixels, as for its coordinates,
/// so a shape that shrinks through 1 px stays small (ledger C15). A percentage is of the slot,
/// and a negative number the slot less that much, as for every element (DESIGN 6).
fn size(p: &Props, key: &str, basis: f32) -> Option<f32> {
    match p.get(key).and_then(crate::style::dim::parse_number) {
        Some(n) if n >= 0.0 => Some(n),
        _ => p.dim(key).map(|d| d.resolve(basis)),
    }
}

/// (box, path, fillable) of an untransformed art element.
fn geometry(node: &Node, origin: (f32, f32), parent: (f32, f32)) -> Option<(Rect, Path, bool)> {
    let p = &node.props;
    let dim = |key: &str, basis: f32| size(p, key, basis);
    let left = origin.0 + coordinate(p, "left", parent.0).unwrap_or(0.0);
    let top = origin.1 + coordinate(p, "top", parent.1).unwrap_or(0.0);
    // Art that names a near and a far edge and no size runs from one to the other.
    let (right, bottom) = far_edges(p, origin, parent);
    let span_w = right.filter(|_| p.has("left")).map(|r| (r - left).max(0.0));
    let span_h = bottom.filter(|_| p.has("top")).map(|b| (b - top).max(0.0));
    let centred = p.truthy("center");
    let boxed = |w: f32, h: f32| {
        if centred {
            Rect::new(left - w / 2.0, top - h / 2.0, w, h)
        } else {
            Rect::new(left, top, w, h)
        }
    };
    match node.kind {
        Kind::Rect => {
            let w = dim("width", parent.0).or(span_w).unwrap_or(0.0);
            let h = dim("height", parent.1).or(span_h).unwrap_or(w);
            let r = boxed(w, h);
            let curve = p.f32("curve").unwrap_or(0.0);
            Some((r, rounded_rect(r, curve)?, true))
        }
        Kind::Oval => {
            let radius = p.f32("radius");
            let w = dim("width", parent.0).or(radius.map(|r| r * 2.0)).or(span_w).unwrap_or(0.0);
            let h = dim("height", parent.1).or(radius.map(|r| r * 2.0)).or(span_h).unwrap_or(w);
            let r = boxed(w, h);
            Some((r, ellipse(r)?, true))
        }
        Kind::Line => {
            let x2 = origin.0 + coordinate(p, "x2", parent.0).unwrap_or(0.0);
            let y2 = origin.1 + coordinate(p, "y2", parent.1).unwrap_or(0.0);
            let mut pb = PathBuilder::new();
            pb.move_to(left, top);
            pb.line_to(x2, y2);
            let pad = p.art_f32("strokewidth").unwrap_or(1.0).max(1.0) / 2.0;
            let bounds = Rect::new(left.min(x2) - pad, top.min(y2) - pad, (x2 - left).abs() + 2.0 * pad, (y2 - top).abs() + 2.0 * pad);
            Some((bounds, pb.finish()?, false))
        }
        Kind::Arrow => {
            let w = dim("width", parent.0).unwrap_or(0.0);
            let path = arrow(left, top, w)?;
            Some((Rect::new(left - w / 2.0, top - 0.4 * w, w, 0.8 * w), path, true))
        }
        Kind::Star => {
            let points = p.f32("points").unwrap_or(10.0).clamp(2.0, 1000.0) as u32;
            let outer = p.f32("outer").unwrap_or(100.0);
            let inner = p.f32("inner").unwrap_or(50.0);
            let path = star(left, top, points, outer, inner)?;
            Some((Rect::new(left - outer, top - outer, outer * 2.0, outer * 2.0), path, true))
        }
        Kind::Arc => {
            let w = dim("width", parent.0).or(span_w).unwrap_or(0.0);
            let h = dim("height", parent.1).or(span_h).unwrap_or(w);
            let r = boxed(w, h);
            let a1 = p.f32("angle1").unwrap_or(0.0);
            let a2 = p.f32("angle2").unwrap_or(0.0);
            let (cx, cy) = r.center();
            let mut pb = PathBuilder::new();
            let e = Ellipse { cx, cy, rx: w / 2.0, ry: h / 2.0 };
            if p.truthy("wedge") {
                pb.move_to(cx, cy);
                append_arc(&mut pb, e, a1, a2, true);
                pb.close();
            } else {
                append_arc(&mut pb, e, a1, a2, false);
            }
            Some((r, pb.finish()?, true))
        }
        Kind::Shape => {
            let path = shape(p.get("shape_commands"), left, top)?;
            let b = path.bounds();
            Some((Rect::new(b.x(), b.y(), b.width(), b.height()), path, true))
        }
        _ => None,
    }
}

/// How far art draws past its layout box, its stroke aside. A star's box is sized by its outer
/// radius (as in Shoes 3); an inner radius longer than that puts its points further out.
pub fn overhang(node: &Node) -> f32 {
    match node.kind {
        Kind::Star => {
            let outer = node.props.f32("outer").unwrap_or(100.0);
            (node.props.f32("inner").unwrap_or(50.0).abs() - outer).max(0.0)
        }
        _ => 0.0,
    }
}

pub fn rounded_rect(r: Rect, radius: f32) -> Option<Path> {
    if r.w <= 0.0 || r.h <= 0.0 {
        return None;
    }
    let radius = radius.min(r.w / 2.0).min(r.h / 2.0).max(0.0);
    if radius == 0.0 {
        return Some(PathBuilder::from_rect(tiny_skia::Rect::from_xywh(r.x, r.y, r.w, r.h)?));
    }
    let k = 0.552_284_8 * radius;
    let (x, y, w, h) = (r.x, r.y, r.w, r.h);
    let mut pb = PathBuilder::new();
    pb.move_to(x + radius, y);
    pb.line_to(x + w - radius, y);
    pb.cubic_to(x + w - radius + k, y, x + w, y + radius - k, x + w, y + radius);
    pb.line_to(x + w, y + h - radius);
    pb.cubic_to(x + w, y + h - radius + k, x + w - radius + k, y + h, x + w - radius, y + h);
    pb.line_to(x + radius, y + h);
    pb.cubic_to(x + radius - k, y + h, x, y + h - radius + k, x, y + h - radius);
    pb.line_to(x, y + radius);
    pb.cubic_to(x, y + radius - k, x + radius - k, y, x + radius, y);
    pb.close();
    pb.finish()
}

pub fn ellipse(r: Rect) -> Option<Path> {
    PathBuilder::from_oval(tiny_skia::Rect::from_xywh(r.x, r.y, r.w, r.h)?)
}

/// An ellipse by centre and radii.
#[derive(Clone, Copy)]
pub struct Ellipse {
    pub cx: f32,
    pub cy: f32,
    pub rx: f32,
    pub ry: f32,
}

/// Appends an elliptical arc clockwise on screen from `a1` to `a2` (radians,
/// 0 = 3 o'clock), like cairo_arc: an `a2` below `a1` wraps round by 2pi.
/// `connect` draws a line from the current point instead of starting a new one.
pub fn append_arc(pb: &mut PathBuilder, e: Ellipse, a1: f32, a2: f32, connect: bool) {
    let Ellipse { cx, cy, rx, ry } = e;
    if !(a1.is_finite() && a2.is_finite()) {
        return;
    }
    let sweep = if a2 >= a1 { (a2 - a1).min(TAU) } else { (a2 - a1).rem_euclid(TAU) };
    let segments = (sweep / FRAC_PI_2).ceil().max(1.0) as usize;
    let step = sweep / segments as f32;
    let k = 4.0 / 3.0 * (step / 4.0).tan();
    let at = |a: f32| (cx + rx * a.cos(), cy + ry * a.sin());
    let start = at(a1);
    if connect {
        pb.line_to(start.0, start.1);
    } else {
        pb.move_to(start.0, start.1);
    }
    for i in 0..segments {
        let t0 = a1 + i as f32 * step;
        let t1 = t0 + step;
        let (p0, p3) = (at(t0), at(t1));
        let c1 = (p0.0 - k * rx * t0.sin(), p0.1 + k * ry * t0.cos());
        let c2 = (p3.0 + k * rx * t1.sin(), p3.1 - k * ry * t1.cos());
        pb.cubic_to(c1.0, c1.1, c2.0, c2.1, p3.0, p3.1);
    }
}

/// Shoes 3's star: first point straight down from the centre, then round by
/// pi/points, alternating outer and inner radius (shape.c:155-172).
pub fn star(cx: f32, cy: f32, points: u32, outer: f32, inner: f32) -> Option<Path> {
    if outer <= 0.0 {
        return None;
    }
    let mut pb = PathBuilder::new();
    pb.move_to(cx, cy + outer);
    for i in 1..=points * 2 {
        let angle = i as f32 * PI / points as f32;
        let r = if i % 2 == 0 { outer } else { inner };
        pb.line_to(cx + r * angle.sin(), cy + r * angle.cos());
    }
    pb.close();
    pb.finish()
}

/// Shoes 3's arrow: centred on (cx, cy), pointing right, 0.8 x width tall.
pub fn arrow(cx: f32, cy: f32, w: f32) -> Option<Path> {
    if w <= 0.0 {
        return None;
    }
    let (h, tip) = (w * 0.8, w * 0.42);
    let x = cx + w / 2.0;
    let mut pb = PathBuilder::new();
    pb.move_to(x, cy);
    pb.line_to(x - tip, cy + h / 2.0);
    pb.line_to(x - tip, cy + h / 4.0);
    pb.line_to(x - w, cy + h / 4.0);
    pb.line_to(x - w, cy - h / 4.0);
    pb.line_to(x - tip, cy - h / 4.0);
    pb.line_to(x - tip, cy - h / 2.0);
    pb.close();
    pb.finish()
}

/// `shape_commands` as one path offset by the shape's (left, top).
pub fn shape(commands: Option<&Value>, dx: f32, dy: f32) -> Option<Path> {
    let commands = commands?.as_array()?;
    let mut pb = PathBuilder::new();
    let mut has_point = false;
    for command in commands {
        let Some(parts) = command.as_array() else { continue };
        let name = parts.first().and_then(Value::as_str).unwrap_or("");
        let n: Vec<f32> = parts.iter().skip(1).filter_map(|v| v.as_f64().map(|f| f as f32)).collect();
        match (name, n.as_slice()) {
            ("move_to", [x, y, ..]) => {
                pb.move_to(x + dx, y + dy);
                has_point = true;
            }
            ("line_to", [x, y, ..]) => {
                if has_point {
                    pb.line_to(x + dx, y + dy);
                } else {
                    pb.move_to(x + dx, y + dy);
                    has_point = true;
                }
            }
            ("curve_to", [x1, y1, x2, y2, x, y, ..]) => {
                if !has_point {
                    pb.move_to(x1 + dx, y1 + dy);
                    has_point = true;
                }
                pb.cubic_to(x1 + dx, y1 + dy, x2 + dx, y2 + dy, x + dx, y + dy);
            }
            ("arc_to", [cx, cy, w, h, a1, a2, ..]) => {
                append_arc(&mut pb, Ellipse { cx: cx + dx, cy: cy + dy, rx: w / 2.0, ry: h / 2.0 }, *a1, *a2, has_point);
                has_point = true;
            }
            _ => {}
        }
    }
    pb.finish()
}

/// rotate/scale/skew from the draw context. They turn the shape about its corner,
/// or about its centre after `transform :center` or with `center: true` (manual
/// 1857-1860, 1115-1121; ledger E10). Shoes turns counter-clockwise for positive degrees.
pub fn art_transform(node: &Node, frame: Rect) -> Transform {
    let props = &node.props;
    let mut t = Transform::identity();
    let context = |key: &str| props.art(key).cloned();
    if let Some(deg) = context("rotate").and_then(|v| v.as_f64()) {
        t = t.pre_concat(Transform::from_rotate(-deg as f32));
    }
    if let Some(Value::Array(s)) = context("scale") {
        let sx = s.first().and_then(Value::as_f64).unwrap_or(1.0) as f32;
        let sy = s.get(1).and_then(Value::as_f64).map(|v| v as f32).unwrap_or(sx);
        t = t.pre_scale(sx, sy);
    }
    if let Some(Value::Array(k)) = context("skew") {
        let kx = k.first().and_then(Value::as_f64).unwrap_or(0.0) as f32;
        let ky = k.get(1).and_then(Value::as_f64).unwrap_or(0.0) as f32;
        t = t.pre_concat(Transform::from_skew(kx.to_radians().tan(), ky.to_radians().tan()));
    }
    if t.is_identity() {
        return t;
    }
    let (px, py) = if turns_about_centre(node) { frame.center() } else { (frame.x, frame.y) };
    Transform::from_translate(px, py).pre_concat(t).pre_concat(Transform::from_translate(-px, -py))
}

/// The corner a turn keeps still is the point the shape's `left` and `top` name: a star's and
/// an arrow's are their centre (ledger E4, E5), as `center: true` makes anything's.
fn turns_about_centre(node: &Node) -> bool {
    let props = &node.props;
    matches!(node.kind, Kind::Star | Kind::Arrow)
        || props.truthy("center")
        || props.art("transform").and_then(Value::as_str).map(|s| s.trim_start_matches(':')) == Some("center")
}

/// `translate(left, top)` moves the pen for the rest of the slot (manual 1862-1868).
/// Lacci sends the running total as `translate: [x, y]`.
fn translation(props: &Props) -> (f32, f32) {
    let Some(Value::Array(xy)) = props.art("translate") else { return (0.0, 0.0) };
    let at = |i: usize| xy.get(i).and_then(Value::as_f64).unwrap_or(0.0) as f32;
    (at(0), at(1))
}

/// The box around `r` once transformed.
pub fn transformed_box(r: Rect, t: Transform) -> Rect {
    if t.is_identity() {
        return r;
    }
    let mut corners = [
        tiny_skia::Point::from_xy(r.x, r.y),
        tiny_skia::Point::from_xy(r.right(), r.y),
        tiny_skia::Point::from_xy(r.x, r.bottom()),
        tiny_skia::Point::from_xy(r.right(), r.bottom()),
    ];
    t.map_points(&mut corners);
    let (mut x0, mut y0, mut x1, mut y1) = (f32::MAX, f32::MAX, f32::MIN, f32::MIN);
    for c in corners {
        (x0, y0, x1, y1) = (x0.min(c.x), y0.min(c.y), x1.max(c.x), y1.max(c.y));
    }
    Rect::new(x0, y0, x1 - x0, y1 - y0)
}

fn line_cap(props: &Props) -> LineCap {
    match props.art("cap").and_then(Value::as_str).map(|s| s.trim_start_matches(':')) {
        Some("curve") | Some("round") => LineCap::Round,
        Some("project") | Some("square") => LineCap::Square,
        _ => LineCap::Butt,
    }
}

/// Fills then strokes an art element. Unset fill and stroke default to black,
/// strokewidth to 1 (Shoes 3); `nofill`/`nostroke` arrive as alpha 0. A shape
/// block paints the art inside it as part of its own path.
pub fn paint_art(canvas: &mut Canvas, doc: &Doc, boxes: &HashMap<Id, LBox>, node: &Node, lbox: &LBox, images: &mut ImageCache) {
    let (path, frame, fillable) = if node.kind == Kind::Shape {
        let Some((path, frame)) = group(doc, boxes, node, lbox) else { return };
        (path, frame, true)
    } else {
        let Some(art) = art(node, lbox.origin, lbox.parent_size) else { return };
        (art.path, art.frame, art.fillable)
    };
    let props = &node.props;
    let transform = art_transform(node, frame);
    if fillable {
        let fill = props.art_paint("fill").unwrap_or(Paint::Solid(Color::BLACK));
        if fill.is_visible() {
            with_shader(&fill, frame, images, |shader| {
                canvas.fill_path(&path, shader, FillRule::Winding, transform, lbox.clip);
            });
        }
    }
    let stroke = props.art_paint("stroke").unwrap_or(Paint::Solid(Color::BLACK));
    let width = props.art_f32("strokewidth").unwrap_or(1.0);
    if stroke.is_visible() && width > 0.0 {
        let style = Stroke { width, line_cap: line_cap(props), line_join: LineJoin::Round, ..Stroke::default() };
        with_shader(&stroke, frame, images, |shader| {
            canvas.stroke_path(&path, shader, &style, transform, lbox.clip);
        });
    }
}

/// Art drawn inside a shape block is part of the shape (manual 1820-1824, ledger E7 and M21).
pub fn in_shape(doc: &Doc, node: &Node) -> bool {
    node.parent.and_then(|p| doc.get(p)).is_some_and(|p| p.kind == Kind::Shape)
}

/// Where the art inside a shape block is measured from: the shape's (left, top).
pub fn group_origin(node: &Node, origin: (f32, f32), parent: (f32, f32)) -> (f32, f32) {
    let at = |key: &str, basis: f32| coordinate(&node.props, key, basis).unwrap_or(0.0);
    (origin.0 + at("left", parent.0), origin.1 + at("top", parent.1))
}

/// A shape block's own path plus every sub-path drawn inside it, as one path to fill
/// once (nonzero winding, like cairo's default) and stroke once. Members join
/// untransformed: the shape's own rotate turns the whole group.
fn group(doc: &Doc, boxes: &HashMap<Id, LBox>, node: &Node, lbox: &LBox) -> Option<(Path, Rect)> {
    let mut pb = PathBuilder::new();
    let mut frame: Option<Rect> = None;
    let mut add = |path: &Path, r: Rect| {
        pb.push_path(path);
        frame = Some(frame.map_or(r, |f| f.union(&r)));
    };
    if let Some(own) = art(node, lbox.origin, lbox.parent_size) {
        add(&own.path, own.frame);
    }
    for &child in doc.children(node.id) {
        let (Some(member), Some(b)) = (doc.get(child), boxes.get(&child)) else { continue };
        let sub = match member.kind {
            Kind::Shape => group(doc, boxes, member, b),
            ref k if k.is_art() => art(member, b.origin, b.parent_size).map(|a| (a.path, a.frame)),
            _ => None,
        };
        if let Some((path, r)) = sub {
            add(&path, r);
        }
    }
    Some((pb.finish()?, frame?))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::doc::{Doc, NewNode};
    use serde_json::json;

    fn node(class: &str, props: Value) -> Node {
        let mut doc = Doc::default();
        doc.create(NewNode {
            id: 1,
            class: class.into(),
            parent: None,
            index: None,
            widget: false,
            props: props.as_object().unwrap().clone(),
            doc_root: None,
            owner: None,
        });
        doc.get(1).unwrap().clone()
    }

    #[test]
    fn star_is_centred_with_outer_radius() {
        let a = art(&node("Star", json!({"left": 100, "top": 100, "points": 5, "outer": 50.0, "inner": 20.0})), (0.0, 0.0), (480.0, 420.0)).unwrap();
        assert_eq!(a.bounds, Rect::new(50.0, 50.0, 100.0, 100.0));
        let b = a.path.bounds();
        assert!((b.bottom() - 150.0).abs() < 0.01, "first point is straight down");
    }

    #[test]
    fn arrow_is_centred() {
        let a = art(&node("Arrow", json!({"left": 100, "top": 50, "width": 40})), (10.0, 0.0), (480.0, 420.0)).unwrap();
        assert_eq!(a.bounds, Rect::new(90.0, 34.0, 40.0, 32.0));
    }

    #[test]
    fn oval_center_style() {
        let a = art(&node("Oval", json!({"left": 50, "top": 50, "width": 20, "height": 10, "center": true})), (0.0, 0.0), (480.0, 420.0)).unwrap();
        assert_eq!(a.bounds, Rect::new(40.0, 45.0, 20.0, 10.0));
    }

    #[test]
    fn arc_sweeps_clockwise() {
        let a = art(&node("Arc", json!({"left": 0, "top": 0, "width": 100, "height": 100, "angle1": 0.0, "angle2": std::f64::consts::PI})), (0.0, 0.0), (480.0, 420.0)).unwrap();
        let b = a.path.bounds();
        assert!(b.top() > 49.0, "a 0..PI arc is the lower half on screen: {b:?}");
    }

    #[test]
    fn shape_commands_offset_by_left_top() {
        let a = art(
            &node("Shape", json!({"left": 10, "top": 20, "shape_commands": [["move_to", 0, 0], ["line_to", 50, 0], ["curve_to", 60, 10, 60, 30, 50, 40], ["arc_to", 25, 40, 50, 50, 0.0, std::f64::consts::PI]]})),
            (0.0, 0.0),
            (480.0, 420.0),
        )
        .unwrap();
        assert!((a.bounds.x - 10.0).abs() < 0.01 && (a.bounds.y - 20.0).abs() < 0.01);
    }

    fn moved(t: Transform, x: f32, y: f32) -> (f32, f32) {
        let mut p = [tiny_skia::Point::from_xy(x, y)];
        t.map_points(&mut p);
        ((p[0].x * 100.0).round() / 100.0, (p[0].y * 100.0).round() / 100.0)
    }

    /// manual 1783-1797: `rotate 45; rect 30, 30, 40, 40` turns about the rect's corner.
    #[test]
    fn rotate_turns_about_the_corner_by_default() {
        let a = art(&node("Rect", json!({"left": 30, "top": 30, "width": 40, "height": 40, "draw_context": {"rotate": 45}})), (0.0, 0.0), (480.0, 420.0)).unwrap();
        assert_eq!(a.frame, Rect::new(30.0, 30.0, 40.0, 40.0));
        assert_eq!(moved(a.transform, 30.0, 30.0), (30.0, 30.0), "the corner stays put");
        assert_eq!(moved(a.transform, 70.0, 70.0), (86.57, 30.0), "the far corner swings up, counter-clockwise");
        assert!((a.bounds.y - 1.72).abs() < 0.01 && (a.bounds.right() - 86.57).abs() < 0.01, "the box follows: {:?}", a.bounds);
    }

    /// manual 1857-1860: `transform :center` turns about the middle instead.
    #[test]
    fn transform_center_turns_about_the_middle() {
        let a = art(
            &node("Rect", json!({"left": 100, "top": 100, "width": 60, "height": 20, "draw_context": {"rotate": 90, "transform": "center"}})),
            (0.0, 0.0),
            (300.0, 300.0),
        )
        .unwrap();
        assert_eq!(moved(a.transform, 130.0, 110.0), (130.0, 110.0));
        assert_eq!(a.bounds, Rect::new(120.0, 80.0, 20.0, 60.0));
    }

    /// A star's and an arrow's `left` and `top` are their centre (ledger E4, E5), so that is the
    /// corner a turn keeps still, as `center: true` would: Hackety Hack's splash spins
    /// `rotate 1; star 210, 210, 130, 500, 90` in place, one degree a frame. It turned about its
    /// box's top-left corner and swung off across the window.
    #[test]
    fn a_star_and_an_arrow_turn_about_the_point_they_are_drawn_at() {
        let star = art(&node("Star", json!({"left": 210, "top": 210, "points": 5, "outer": 100, "inner": 50, "draw_context": {"rotate": 30}})), (0.0, 0.0), (480.0, 420.0)).unwrap();
        assert_eq!(moved(star.transform, 210.0, 210.0), (210.0, 210.0), "the star's centre stays put");
        assert_eq!(star.bounds.center(), (210.0, 210.0));
        let arrow = art(&node("Arrow", json!({"left": 100, "top": 100, "width": 40, "draw_context": {"rotate": 90}})), (0.0, 0.0), (480.0, 420.0)).unwrap();
        assert_eq!(moved(arrow.transform, 100.0, 100.0), (100.0, 100.0), "so does the arrow's");
    }

    /// manual 1115-1121: `center: true` places by the centre, and turns about it too.
    #[test]
    fn center_style_turns_about_the_middle() {
        let a = art(&node("Rect", json!({"left": 50, "top": 50, "width": 20, "height": 10, "center": true, "draw_context": {"rotate": 90}})), (0.0, 0.0), (480.0, 420.0)).unwrap();
        assert_eq!(moved(a.transform, 50.0, 50.0), (50.0, 50.0));
    }

    /// manual 1862-1868: after translate(10, 20) a shape drawn at (50, 60) lands at (60, 80).
    #[test]
    fn translate_moves_the_shape_and_its_box() {
        let a = art(&node("Rect", json!({"left": 50, "top": 60, "width": 20, "height": 20, "draw_context": {"translate": [10, 20]}})), (5.0, 0.0), (200.0, 200.0)).unwrap();
        assert_eq!(a.frame, Rect::new(65.0, 80.0, 20.0, 20.0));
        assert_eq!(a.bounds, a.frame);
        assert!(a.transform.is_identity());
    }

    #[test]
    fn line_goes_between_points() {
        let a = art(&node("Line", json!({"left": 10, "top": 10, "x2": 110, "y2": 10})), (0.0, 0.0), (480.0, 420.0)).unwrap();
        assert!(!a.fillable);
        assert_eq!(a.bounds, Rect::new(9.5, 9.5, 101.0, 1.0));
    }
}
