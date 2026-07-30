import CoreGraphics
import Foundation
import Testing
@testable import Gin

/// A two-stroke glyph, roughly a "T".
private func sampleGlyph() -> GlyphTrace {
    func line(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> TraceStroke {
        TraceStroke(points: (0 ..< 12).map { step in
            let t = Double(step) / 11
            return TracePoint(x: x0 + (x1 - x0) * t, y: y0 + (y1 - y0) * t)
        })
    }
    return GlyphTrace(strokes: [line(0.2, 0.1, 0.8, 0.1), line(0.5, 0.1, 0.5, 0.9)])
}

/// Ink that follows the guide exactly.
private func perfectInk(for glyph: GlyphTrace) -> [[CGPoint]] {
    glyph.strokes.map(\.cgPoints)
}

/// Ink that follows the guide but wobbles, the way a real child's hand does.
private func wobblyInk(for glyph: GlyphTrace, by amount: Double) -> [[CGPoint]] {
    glyph.strokes.enumerated().map { strokeIndex, stroke in
        stroke.cgPoints.enumerated().map { pointIndex, point in
            // Deterministic zig-zag rather than random, so failures reproduce.
            let sign: Double = (pointIndex + strokeIndex).isMultiple(of: 2) ? 1 : -1
            return CGPoint(x: point.x + amount * sign, y: point.y - amount * sign)
        }
    }
}

struct TraceEvaluatorTests {

    @Test("A perfect trace completes the glyph")
    func perfectTraceCompletes() {
        let glyph = sampleGlyph()
        let result = TraceEvaluator().assess(guide: glyph, ink: perfectInk(for: glyph))

        #expect(result.isComplete)
        #expect(result.coveredStrokes == [0, 1])
        #expect(result.coverage > 0.99)
        #expect(result.precision > 0.99)
    }

    @Test("A wobbly but honest trace still completes")
    func wobbleIsForgiven() {
        let glyph = sampleGlyph()
        // Well inside the 0.09 tolerance — a four-year-old's line.
        let result = TraceEvaluator().assess(guide: glyph, ink: wobblyInk(for: glyph, by: 0.04))

        #expect(result.isComplete, "coverage \(result.coverage), precision \(result.precision)")
    }

    @Test("An empty canvas completes nothing")
    func emptyInkIsIncomplete() {
        let result = TraceEvaluator().assess(guide: sampleGlyph(), ink: [])
        #expect(!result.isComplete)
        #expect(result.coverage == 0)
        #expect(result.precision == 0)
        #expect(result.coveredStrokes.isEmpty)
    }

    /// A dense uniform raster. This is the test that gave false confidence:
    /// it passes on precision alone, but it is not what a real scribble looks
    /// like once PencilKit has smoothed it.
    @Test("A dense raster over the whole box is not writing")
    func denseRasterIsRejected() {
        let glyph = sampleGlyph()

        var scribble: [CGPoint] = []
        for row in 0 ..< 40 {
            for column in 0 ..< 40 {
                scribble.append(CGPoint(x: Double(column) / 39, y: Double(row) / 39))
            }
        }

        let result = TraceEvaluator().assess(guide: glyph, ink: [scribble])
        #expect(!result.isComplete)
    }

    /// The scribble that actually fooled the running app: a coarse zigzag of a
    /// dozen sweeps across the canvas. It survived the precision check because
    /// PencilKit's smoothing pulls it toward the middle of the box. Length is
    /// what catches it.
    @Test("A coarse zigzag across the canvas is not writing")
    func coarseZigzagIsRejected() {
        let glyph = sampleGlyph()

        var zigzag: [CGPoint] = []
        for sweep in 0 ..< 12 {
            let y = 0.05 + Double(sweep) * 0.08
            let leftToRight = sweep.isMultiple(of: 2)
            for step in 0 ..< 24 {
                let t = Double(step) / 23
                zigzag.append(CGPoint(x: leftToRight ? t : 1 - t, y: y))
            }
        }

        let result = TraceEvaluator().assess(guide: glyph, ink: [zigzag])
        let evaluator = TraceEvaluator()

        #expect(result.coverage > 0.5, "it does cross the guide")
        #expect(evaluator.lengthRatio(of: [zigzag], against: glyph) > 2.5,
                "and it is far longer than the glyph")
        #expect(!result.isComplete, "so it must not complete the glyph")
    }

    @Test("Going over a stroke twice still counts")
    func doubledTraceIsForgiven() {
        let glyph = sampleGlyph()
        // A child retracing to be sure roughly doubles the length. Must pass.
        let doubled = glyph.strokes.map { $0.cgPoints + $0.cgPoints.reversed() }
        #expect(TraceEvaluator().assess(guide: glyph, ink: doubled).isComplete)
    }

    @Test("Tracing one stroke of two leaves the glyph open")
    func partialTraceIsPartial() {
        let glyph = sampleGlyph()
        let firstOnly = [glyph.strokes[0].cgPoints]

        let result = TraceEvaluator().assess(guide: glyph, ink: firstOnly)

        #expect(result.coveredStrokes == [0])
        #expect(!result.isComplete)
    }

    @Test("Ink far from the glyph covers nothing")
    func farAwayInkMisses() {
        let glyph = sampleGlyph()
        // A short mark in the corner, away from both strokes.
        let stray = [[CGPoint(x: 0.05, y: 0.95), CGPoint(x: 0.10, y: 0.95)]]

        let result = TraceEvaluator().assess(guide: glyph, ink: stray)

        #expect(result.coveredStrokes.isEmpty)
        #expect(!result.isComplete)
    }

    @Test("A glyph with no strokes cannot be completed")
    func emptyGuideIsSafe() {
        let result = TraceEvaluator().assess(guide: GlyphTrace(strokes: []), ink: [])
        #expect(!result.isComplete)
    }
}

struct WritingPackTests {

    private func writingPack() throws -> Pack {
        try ContentLoader.load("writing", from: .main)
    }

    @Test("The writing pack loads and only offers tracing")
    func packLoads() throws {
        let pack = try writingPack()
        #expect(pack.mechanics == [.trace])
        #expect(pack.color == .ink)
        // Available from the youngest level, because the pack opens with the four
        // pre-writing strokes — the genuine prerequisite for letter formation and
        // the one part of this a two-year-old can do. Letters are a few taps in.
        #expect(pack.minLevel == .little)
    }

    @Test("Every glyph carries a usable trace")
    func everyGlyphHasStrokes() throws {
        for item in try writingPack().items {
            let trace = try #require(item.trace, "\(item.id) has no trace")
            #expect(!trace.strokes.isEmpty, "\(item.id) has no strokes")
            for (index, stroke) in trace.strokes.enumerated() {
                #expect(stroke.points.count >= 2,
                        "\(item.id) stroke \(index) has \(stroke.points.count) points")
            }
        }
    }

    @Test("Every stroke point sits inside the glyph box")
    func pointsAreNormalized() throws {
        for item in try writingPack().items {
            let trace = try #require(item.trace)
            for stroke in trace.strokes {
                for point in stroke.points {
                    #expect(point.x >= 0 && point.x <= 1, "\(item.id) x=\(point.x)")
                    #expect(point.y >= 0 && point.y <= 1, "\(item.id) y=\(point.y)")
                }
            }
        }
    }

    /// Pre-writing strokes are the actual prerequisite for letter formation, and
    /// the only part of this pack a two-year-old can do. They must come first.
    @Test("Pre-writing strokes come before any letter")
    func preWritingComesFirst() throws {
        let items = try writingPack().items
        let firstLetter = try #require(items.firstIndex { $0.tags.contains("letter") })
        let lastPreWriting = try #require(items.lastIndex { $0.tags.contains("prewriting") })
        #expect(lastPreWriting < firstLetter)
    }

    @Test("The alphabet comes before the digits, and both are complete")
    func lettersThenDigits() throws {
        let items = try writingPack().items
        let letters = items.filter { $0.tags.contains("letter") }
        let digits = items.filter { $0.tags.contains("digit") }

        #expect(letters.count == 26)
        #expect(digits.count == 10)
        #expect(letters.map(\.name) == (65 ... 90).map { String(UnicodeScalar($0)!) })

        let firstDigit = try #require(items.firstIndex { $0.tags.contains("digit") })
        let lastLetter = try #require(items.lastIndex { $0.tags.contains("letter") })
        #expect(lastLetter < firstDigit)
    }

    /// Each glyph should be traceable in a handful of strokes. More than four means
    /// the authoring drifted from how the character is actually taught.
    @Test("No glyph needs more than four strokes")
    func strokeCountsAreSane() throws {
        for item in try writingPack().items {
            let trace = try #require(item.trace)
            #expect(trace.strokes.count <= 4,
                    "\(item.id) needs \(trace.strokes.count) strokes")
        }
    }

    @Test("A perfect trace of every real glyph completes it")
    func everyAuthoredGlyphIsCompletable() throws {
        let evaluator = TraceEvaluator()
        for item in try writingPack().items {
            let trace = try #require(item.trace)
            let ink = trace.strokes.map(\.cgPoints)
            let result = evaluator.assess(guide: trace, ink: ink)
            #expect(result.isComplete, "\(item.id) cannot be completed even traced exactly")
        }
    }
}
