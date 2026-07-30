import CoreGraphics
import Foundation

/// How well a child's ink follows one glyph.
struct TraceAssessment: Equatable, Sendable {
    /// Which guide strokes have been followed well enough.
    var coveredStrokes: Set<Int>
    /// Fraction of the whole glyph followed, 0...1.
    var coverage: Double
    /// Fraction of the child's ink that stayed near the guide, 0...1.
    var precision: Double

    var isComplete: Bool = false
}

/// Decides whether a traced glyph counts.
///
/// Pulled out of the view and expressed entirely in normalized 0...1 space so it
/// can be tested without a canvas, a Pencil, or a screen.
///
/// ## Why there are two measures
///
/// **Coverage** alone is trivially cheated: scribbling over the whole box covers
/// every checkpoint. **Precision** — how much of the ink stayed near the guide —
/// is what distinguishes writing from scribbling.
///
/// Both thresholds are deliberately generous. A four-year-old's B will wobble
/// badly off the line and should still count; the bar being cleared here is
/// "you followed the shape", not "your handwriting is neat". Nothing in Gin can
/// be failed, so a glyph that does not pass simply stays open — the child is
/// never told they got it wrong.
struct TraceEvaluator: Sendable {
    /// How far the ink may stray and still count, as a fraction of the box.
    var tolerance: Double = 0.09
    /// Fraction of a stroke's checkpoints that must be hit for it to count.
    var requiredStrokeCoverage: Double = 0.70
    /// Fraction of ink that must be near the guide, to rule out scribbling.
    var requiredPrecision: Double = 0.45
    /// How much longer than the guide the child's ink may be.
    ///
    /// The measure that actually separates tracing from scribbling. Precision
    /// alone does not: PencilKit fits a smoothed spline, so a fast scribble
    /// collapses toward the middle of the box and keeps a decent fraction of
    /// its ink near the guide. But a scribble is *many times longer* than the
    /// glyph it covers, and tracing is not.
    ///
    /// 2.5 is deliberately loose — going over a stroke twice to be sure, or
    /// overshooting the ends, is normal for a small child and must still pass.
    var maxInkLengthRatio: Double = 2.5
    /// Precision is measured more loosely than coverage — ink naturally overshoots
    /// the ends of a stroke, and punishing that would make crossbars impossible.
    var precisionToleranceScale: Double = 1.8

    /// - Parameters:
    ///   - guide: the glyph being traced.
    ///   - ink: the child's strokes, in the same normalized space.
    func assess(guide: GlyphTrace, ink: [[CGPoint]]) -> TraceAssessment {
        guard !guide.strokes.isEmpty else {
            return TraceAssessment(coveredStrokes: [], coverage: 0, precision: 0)
        }

        let inkPoints = ink.flatMap { $0 }

        var covered: Set<Int> = []
        var hitCheckpoints = 0
        var totalCheckpoints = 0

        for (index, stroke) in guide.strokes.enumerated() {
            let checkpoints = stroke.cgPoints
            guard !checkpoints.isEmpty else { continue }

            let hits = checkpoints.filter { checkpoint in
                nearestDistance(from: checkpoint, to: inkPoints) <= tolerance
            }.count

            totalCheckpoints += checkpoints.count
            hitCheckpoints += hits

            if Double(hits) / Double(checkpoints.count) >= requiredStrokeCoverage {
                covered.insert(index)
            }
        }

        let coverage = totalCheckpoints == 0
            ? 0
            : Double(hitCheckpoints) / Double(totalCheckpoints)

        let precision = self.precision(of: inkPoints, against: guide)

        // Complete only when every stroke was followed, the ink largely stayed
        // on the glyph, *and* the child did not simply cover the box. All
        // three, or it is a scribble.
        let isComplete = covered.count == guide.strokes.count
            && precision >= requiredPrecision
            && lengthRatio(of: ink, against: guide) <= maxInkLengthRatio

        return TraceAssessment(
            coveredStrokes: covered,
            coverage: coverage,
            precision: precision,
            isComplete: isComplete
        )
    }

    /// Fraction of the child's ink that lies near the guide.
    func precision(of inkPoints: [CGPoint], against guide: GlyphTrace) -> Double {
        guard !inkPoints.isEmpty else { return 0 }
        let guidePoints = guide.strokes.flatMap(\.cgPoints)
        guard !guidePoints.isEmpty else { return 0 }

        let limit = tolerance * precisionToleranceScale
        let onPath = inkPoints.filter { point in
            nearestDistance(from: point, to: guidePoints) <= limit
        }.count
        return Double(onPath) / Double(inkPoints.count)
    }

    /// Total ink length divided by total guide length.
    func lengthRatio(of ink: [[CGPoint]], against guide: GlyphTrace) -> Double {
        let guideLength = guide.strokes.reduce(0.0) { $0 + polylineLength($1.cgPoints) }
        guard guideLength > 0 else { return .greatestFiniteMagnitude }
        let inkLength = ink.reduce(0.0) { $0 + polylineLength($1) }
        return inkLength / guideLength
    }

    private func polylineLength(_ points: [CGPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0.0) { total, pair in
            let dx = Double(pair.1.x - pair.0.x)
            let dy = Double(pair.1.y - pair.0.y)
            return total + (dx * dx + dy * dy).squareRoot()
        }
    }

    private func nearestDistance(from point: CGPoint, to candidates: [CGPoint]) -> Double {
        var best = Double.greatestFiniteMagnitude
        for candidate in candidates {
            let dx = Double(candidate.x - point.x)
            let dy = Double(candidate.y - point.y)
            let squared = dx * dx + dy * dy
            if squared < best { best = squared }
            // Already inside the tightest threshold we ever test against.
            if best == 0 { break }
        }
        return best.squareRoot()
    }
}
