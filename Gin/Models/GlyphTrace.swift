import CoreGraphics
import Foundation

/// A point in a glyph's normalized 0...1 box, origin top-left.
struct TracePoint: Codable, Sendable, Hashable {
    var x: Double
    var y: Double

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

/// One continuous pen stroke. Lifting the pencil ends it.
struct TraceStroke: Codable, Sendable, Hashable {
    var points: [TracePoint]

    var cgPoints: [CGPoint] { points.map(\.cgPoint) }

    /// Where the child should start. Rendered as the green dot.
    var start: CGPoint? { points.first?.cgPoint }
}

/// The path a pen travels to write one glyph.
///
/// This is a **centerline**, not an outline, and the strokes are in the order a
/// child is taught to draw them. That distinction is the whole feature: a font
/// would give an outline, and tracing the outline of "O" means tracing two
/// concentric circles rather than writing an O.
///
/// Authored by `Tools/generate_writing_pack.py`.
struct GlyphTrace: Codable, Sendable, Hashable {
    var strokes: [TraceStroke]

    /// Denormalizes into a drawing rect.
    func strokes(in size: CGSize) -> [[CGPoint]] {
        strokes.map { stroke in
            stroke.cgPoints.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        }
    }
}
