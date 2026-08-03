import Foundation

/// One drawable figure: a shape, repeated, in a colour, at a size.
///
/// Four independent attributes is the whole vocabulary, and that is deliberate.
/// Non-verbal reasoning puzzles are built by varying attributes along axes, so
/// the number of attributes *is* the ceiling on how hard a puzzle can get. Four
/// gives room for a 3×3 with two interacting rules — genuinely hard — without
/// needing artwork, rotation, or anything a child has to be taught to read.
struct LogicFigure: Equatable, Hashable, Sendable {
    enum Shape: String, CaseIterable, Sendable {
        case circle, square, triangle, star, diamond, heart
    }

    enum Size: Int, CaseIterable, Comparable, Sendable {
        case small = 0, medium, large
        static func < (lhs: Size, rhs: Size) -> Bool { lhs.rawValue < rhs.rawValue }

        var scale: Double {
            switch self {
            case .small: 0.55
            case .medium: 0.78
            case .large: 1.0
            }
        }
    }

    var shape: Shape
    var color: PackColor
    /// How many copies of the shape sit in the cell, 1...3.
    var count: Int
    var size: Size

    /// Spoken aloud when a child taps a figure, so the pack works for a
    /// pre-reader the same way every other pack does.
    var spokenDescription: String {
        let noun = count == 1 ? shape.rawValue : "\(shape.rawValue)s"
        return count == 1 ? "\(color.rawValue) \(noun)" : "\(count) \(color.rawValue) \(noun)"
    }
}

/// The attribute a rule varies along one axis of a puzzle.
enum FigureAttribute: CaseIterable, Sendable {
    case shape, color, count, size
}

/// Difficulty rungs, easy to genuinely hard.
///
/// The ladder is the point of this pack: the same screen has to work for a
/// three-year-old spotting the odd duck and for an adult doing a 3×3 with two
/// interacting rules. Tiers unlock with success and never lock again.
enum LogicTier: Int, CaseIterable, Codable, Sendable, Comparable {
    /// Three identical figures and one that differs in a single attribute.
    case oddOneOutIdentical = 1
    /// Three that share one property, one that breaks it — the others differ
    /// from each other too, so identity matching no longer works.
    case oddOneOutCategory
    /// 2×2 grid, one attribute changing across the columns.
    case matrix2x2Single
    /// 2×2 grid, a different attribute changing down the rows as well.
    case matrix2x2Double
    /// 3×3 grid, two interacting rules. Raven's territory.
    case matrix3x3Double
    /// 3×3 where one of the rules is a running count, which has to be inferred
    /// rather than matched.
    case matrix3x3Progression

    static func < (lhs: LogicTier, rhs: LogicTier) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Shown in the parent zone, never to the child.
    var parentFacingName: String {
        switch self {
        case .oddOneOutIdentical: "Odd one out"
        case .oddOneOutCategory: "Odd one out — by property"
        case .matrix2x2Single: "Grid, one rule"
        case .matrix2x2Double: "Grid, two rules"
        case .matrix3x3Double: "Big grid, two rules"
        case .matrix3x3Progression: "Big grid, counting rule"
        }
    }

    var isOddOneOut: Bool {
        self == .oddOneOutIdentical || self == .oddOneOutCategory
    }
}

/// A generated puzzle, ready to draw.
struct LogicPuzzle: Identifiable, Equatable {
    let id = UUID()
    let tier: LogicTier

    let rows: Int
    let columns: Int
    /// Row-major. `nil` is the cell the child has to fill.
    let cells: [LogicFigure?]

    /// Offered below the grid. Empty for odd-one-out, where the grid *is* the
    /// answer set and the child taps a cell directly.
    let choices: [LogicFigure]
    let answer: LogicFigure

    var isOddOneOut: Bool { tier.isOddOneOut }

    var prompt: String {
        isOddOneOut ? "Which one is different?" : "Which one is missing?"
    }

    static func == (lhs: LogicPuzzle, rhs: LogicPuzzle) -> Bool { lhs.id == rhs.id }
}
