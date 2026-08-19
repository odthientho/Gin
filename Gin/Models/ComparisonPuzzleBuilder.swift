import Foundation

/// Generates size-comparison puzzles.
///
/// ## The one rule that matters
///
/// Every figure in a puzzle shares a shape and a colour. Only size varies.
///
/// That is not for tidiness. If the bigger circle is also the red one, a child
/// can answer every question correctly without ever comparing sizes, and neither
/// they nor anyone watching would find out. Holding everything else constant is
/// what makes the question actually about size.
///
/// ## The second rule
///
/// Sizes must be far enough apart to *see*. Two figures four percent apart make
/// an unfair question rather than a hard one — the child is right that they look
/// the same. Each rung declares a ``ComparisonTier/minimumRatio`` and the
/// generator never produces anything closer.
enum ComparisonPuzzleBuilder {

    static let answersToUnlockNextTier = 4

    /// Colours a figure may take. Only one is used per puzzle.
    static let palette: [PackColor] = [.berry, .sky, .leaf, .sun, .grape, .mango]

    static func puzzle(
        upTo ceiling: ComparisonTier,
        using generator: inout some RandomNumberGenerator
    ) -> ComparisonPuzzle {
        let available = ComparisonTier.allCases.filter { $0 <= ceiling }
        let tier: ComparisonTier
        if available.count == 1 || Int.random(in: 0 ..< 100, using: &generator) < 60 {
            tier = ceiling
        } else {
            tier = available.dropLast().randomElement(using: &generator) ?? ceiling
        }
        return puzzle(tier: tier, using: &generator)
    }

    static func puzzle(
        tier: ComparisonTier,
        using generator: inout some RandomNumberGenerator
    ) -> ComparisonPuzzle {
        let shape = LogicFigure.Shape.allCases.randomElement(using: &generator) ?? .circle
        let color = palette.randomElement(using: &generator) ?? .sky

        func figure(_ scale: Double) -> ComparisonFigure {
            ComparisonFigure(shape: shape, color: color, scale: scale)
        }

        switch tier {
        case .sameSize:
            // A reference, one true match, and two clear non-matches. The
            // distractors sit either side so "same" cannot be reached by always
            // picking the biggest or always the smallest.
            let base = Double.random(in: 0.46 ... 0.62, using: &generator)
            let ratio = tier.minimumRatio
            let candidates = [
                figure(base),                    // the match
                figure(base * ratio),            // clearly larger
                figure(base / ratio)             // clearly smaller
            ]
            let match = candidates[0]
            return ComparisonPuzzle(
                tier: tier,
                question: .sameSize,
                reference: figure(base),
                figures: candidates.shuffled(using: &generator),
                answer: match,
                orderedAnswer: []
            )

        case .putInOrder:
            let ascending = Bool.random(using: &generator)
            let figures = scales(
                count: tier.figureCount,
                minimumRatio: tier.minimumRatio,
                using: &generator
            ).map(figure)
            let sorted = ascending
                ? figures.sorted { $0.scale < $1.scale }
                : figures.sorted { $0.scale > $1.scale }
            return ComparisonPuzzle(
                tier: tier,
                question: .order(ascending: ascending),
                reference: nil,
                figures: figures.shuffled(using: &generator),
                answer: nil,
                orderedAnswer: sorted.map(\.id)
            )

        default:
            let wantsLargest = Bool.random(using: &generator)
            let figures = scales(
                count: tier.figureCount,
                minimumRatio: tier.minimumRatio,
                using: &generator
            ).map(figure)
            let target = wantsLargest
                ? figures.max { $0.scale < $1.scale }
                : figures.min { $0.scale < $1.scale }
            let question: ComparisonQuestion = figures.count == 2
                ? .comparative(wantsLargest: wantsLargest)
                : .superlative(wantsLargest: wantsLargest)
            return ComparisonPuzzle(
                tier: tier,
                question: question,
                reference: nil,
                figures: figures.shuffled(using: &generator),
                answer: target,
                orderedAnswer: []
            )
        }
    }

    /// Ascending scales, each at least `minimumRatio` times the one below, all
    /// within the drawable range.
    ///
    /// Built upward from the smallest and then normalised, rather than picked at
    /// random and checked: picking randomly and rejecting collisions can loop for
    /// a long time once four figures have to fit inside one order of magnitude.
    static func scales(
        count: Int,
        minimumRatio: Double,
        using generator: inout some RandomNumberGenerator
    ) -> [Double] {
        var result: [Double] = [1.0]
        for _ in 1 ..< max(1, count) {
            // A little slack above the minimum so every puzzle is not identically
            // spaced, but never below it.
            let ratio = Double.random(in: minimumRatio ... (minimumRatio * 1.18),
                                      using: &generator)
            result.append((result.last ?? 1) * ratio)
        }

        // Normalise so the largest fills the cell. Ratios are scale-invariant,
        // so this cannot disturb the gaps.
        let largest = result.last ?? 1
        return result.map { $0 / largest }
    }

    /// Ratio and figure count together fix how small the smallest figure gets:
    /// it lands at `1 / ratio^(count - 1)`, and there is no way to raise it
    /// without either narrowing the gaps or dropping a figure. Squeezing the
    /// sizes together to keep the smallest large would trade a fair question for
    /// a visible one, which is the wrong way round — so the rungs are tuned to
    /// leave the smallest visible, and a test holds every one of them to it.
}
