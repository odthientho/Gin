import Foundation

/// One figure in a size comparison.
///
/// Scale is continuous rather than the three fixed steps ``LogicFigure`` uses:
/// ordering four things by size needs four distinguishable sizes, and "a bit
/// bigger" has to be expressible for the harder rungs.
struct ComparisonFigure: Equatable, Hashable, Sendable, Identifiable {
    let id = UUID()
    /// Reused from the Logic pack — the same set of drawable outlines.
    var shape: LogicFigure.Shape
    var color: PackColor
    /// Fraction of the cell the figure fills, 0...1.
    var scale: Double

    static func == (lhs: ComparisonFigure, rhs: ComparisonFigure) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// What a puzzle asks for.
enum ComparisonQuestion: Equatable, Sendable {
    /// Two figures: which is bigger, or which is smaller.
    case comparative(wantsLargest: Bool)
    /// Three or more: which is biggest, or which is smallest.
    case superlative(wantsLargest: Bool)
    /// A reference figure, then candidates: which matches its size.
    case sameSize
    /// Tap all of them in order, smallest first.
    case order(ascending: Bool)

    /// Read aloud. Comparative for two things, superlative for more — which is
    /// how the words actually work, and worth a child hearing correctly even
    /// before they can say why.
    var spoken: String {
        switch self {
        case .comparative(let wantsLargest):
            wantsLargest ? "Which one is bigger?" : "Which one is smaller?"
        case .superlative(let wantsLargest):
            wantsLargest ? "Which one is the biggest?" : "Which one is the smallest?"
        case .sameSize:
            "Which one is the same size?"
        case .order(let ascending):
            ascending ? "Tap them from smallest to biggest"
                      : "Tap them from biggest to smallest"
        }
    }

    var isOrdering: Bool {
        if case .order = self { return true }
        return false
    }
}

/// Difficulty rungs for comparing sizes.
enum ComparisonTier: Int, CaseIterable, Codable, Sendable, Comparable {
    /// Two figures, one obviously larger. The first comparison a child makes.
    case bigOrSmall = 1
    /// A reference and three candidates: which is the *same* size. Equality is
    /// its own idea and does not come free with bigger and smaller.
    case sameSize
    /// Two figures again, but a much narrower gap, so it stops being obvious.
    case closerCall
    /// Three or four figures — a superlative needs the whole set compared, not
    /// just a pair, which is a genuinely different operation.
    case biggestSmallest
    /// Put four in order. Seriation: every pair has to hold at once.
    case putInOrder

    static func < (lhs: ComparisonTier, rhs: ComparisonTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// How many times larger each figure must be than the next one down.
    ///
    /// The single most important number here. Two circles four percent apart is
    /// not a hard question, it is an unfair one — the child is right that they
    /// look the same. Gaps stay wide enough to see, and narrow only where the
    /// rung is meant to get harder.
    var minimumRatio: Double {
        switch self {
        case .bigOrSmall: 1.9
        case .sameSize: 1.55
        case .closerCall: 1.35
        case .biggestSmallest: 1.3
        case .putInOrder: 1.28
        }
    }

    var figureCount: Int {
        switch self {
        case .bigOrSmall, .closerCall: 2
        case .sameSize: 4       // one reference plus three candidates
        case .biggestSmallest: 3
        case .putInOrder: 4
        }
    }

    /// Shown in the parent zone, never to the child.
    var parentFacingName: String {
        switch self {
        case .bigOrSmall: "Bigger and smaller"
        case .sameSize: "The same size"
        case .closerCall: "A closer call"
        case .biggestSmallest: "Biggest and smallest"
        case .putInOrder: "Put in order"
        }
    }
}

/// A generated comparison question.
struct ComparisonPuzzle: Identifiable, Equatable {
    let id = UUID()
    let tier: ComparisonTier
    let question: ComparisonQuestion

    /// Shown above the choices for ``ComparisonQuestion/sameSize``; nil otherwise.
    let reference: ComparisonFigure?
    /// The figures offered, already shuffled.
    let figures: [ComparisonFigure]

    /// For a single-answer question. Empty when ordering.
    let answer: ComparisonFigure?
    /// For ordering: the ids in the order they must be tapped.
    let orderedAnswer: [ComparisonFigure.ID]

    static func == (lhs: ComparisonPuzzle, rhs: ComparisonPuzzle) -> Bool { lhs.id == rhs.id }
}
