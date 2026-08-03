import Foundation

/// Generates the Logic pack's puzzles.
///
/// Generated rather than authored, because the puzzle space is combinatorial: a
/// handful of rules over four attributes yields more distinct 3×3 matrices than
/// anyone would ever write by hand, and a child who replays the pack should not
/// meet the same grid twice.
///
/// ## What makes a distractor good
///
/// The hard part of a reasoning puzzle is not the answer, it is the wrong
/// answers. A distractor picked at random is rejected on sight and the puzzle
/// collapses into "spot the one that looks plausible". So every distractor here
/// is the correct answer with **exactly one attribute changed** — each one is
/// what you would land on by following all the rules but one. That is how real
/// matrix tests are built, and it is what makes tier 5 actually hard.
enum LogicPuzzleBuilder {

    /// Correct answers in a row before the next tier unlocks.
    static let answersToUnlockNextTier = 4

    /// Colours the figures are drawn in. A deliberately small, high-contrast set
    /// — colour is one of the *rules*, so two colours a child might confuse would
    /// make a puzzle unfair rather than hard.
    static let palette: [PackColor] = [.berry, .sky, .leaf, .sun, .grape]

    // MARK: - Entry point

    /// Builds a puzzle at or below `ceiling`, weighted toward the hardest tier
    /// unlocked.
    ///
    /// Sampling below the ceiling rather than always at it keeps earlier rungs in
    /// circulation, so a child who has reached 3×3 still meets an odd-one-out
    /// now and then. It also means a child who unlocks a tier they were lucky on
    /// is never stranded there.
    static func puzzle(
        upTo ceiling: LogicTier,
        using generator: inout some RandomNumberGenerator
    ) -> LogicPuzzle {
        let available = LogicTier.allCases.filter { $0 <= ceiling }
        // Weight the top tier heavily; everything below shares the remainder.
        let tier: LogicTier
        if available.count == 1 || Int.random(in: 0 ..< 100, using: &generator) < 60 {
            tier = ceiling
        } else {
            tier = available.dropLast().randomElement(using: &generator) ?? ceiling
        }
        return puzzle(tier: tier, using: &generator)
    }

    static func puzzle(
        tier: LogicTier,
        using generator: inout some RandomNumberGenerator
    ) -> LogicPuzzle {
        switch tier {
        case .oddOneOutIdentical:
            oddOneOut(sharingIdentity: true, using: &generator)
        case .oddOneOutCategory:
            oddOneOut(sharingIdentity: false, using: &generator)
        case .matrix2x2Single:
            matrix(tier: tier, size: 2, ruleCount: 1, progression: false, using: &generator)
        case .matrix2x2Double:
            matrix(tier: tier, size: 2, ruleCount: 2, progression: false, using: &generator)
        case .matrix3x3Double:
            matrix(tier: tier, size: 3, ruleCount: 2, progression: false, using: &generator)
        case .matrix3x3Progression:
            matrix(tier: tier, size: 3, ruleCount: 2, progression: true, using: &generator)
        }
    }

    // MARK: - Odd one out

    private static func oddOneOut(
        sharingIdentity: Bool,
        using generator: inout some RandomNumberGenerator
    ) -> LogicPuzzle {
        let base = randomFigure(using: &generator)
        // The attribute the odd figure breaks.
        let broken = FigureAttribute.allCases.randomElement(using: &generator) ?? .color

        var others: [LogicFigure] = []
        if sharingIdentity {
            others = Array(repeating: base, count: 3)
        } else {
            // The three keep the shared attribute but differ from each other on
            // another, so the child must reason about a property rather than
            // match pictures.
            //
            // Those three values must be *distinct*. Two siblings alike and one
            // different would create a second three-versus-one split, and the
            // puzzle would have two defensible answers — which is worse than
            // being too hard, because the child is right and told they are wrong.
            let noise = FigureAttribute.allCases
                .filter { $0 != broken }
                .randomElement(using: &generator) ?? .size
            let values = distinctValues(of: noise, count: 3, using: &generator)
            others = values.map { apply($0, to: base) }
        }

        let odd = vary(base, attribute: broken, using: &generator)

        var cells = others
        cells.insert(odd, at: Int.random(in: 0 ... others.count, using: &generator))

        return LogicPuzzle(
            tier: sharingIdentity ? .oddOneOutIdentical : .oddOneOutCategory,
            rows: 1,
            columns: cells.count,
            cells: cells.map { Optional($0) },
            choices: [],
            answer: odd
        )
    }

    // MARK: - Matrices

    private static func matrix(
        tier: LogicTier,
        size: Int,
        ruleCount: Int,
        progression: Bool,
        using generator: inout some RandomNumberGenerator
    ) -> LogicPuzzle {
        // `count` is reserved for the progression rule when there is one, so the
        // running total is never also used as a plain row/column label.
        var usable = FigureAttribute.allCases
        if progression { usable.removeAll { $0 == .count } }

        let shuffled = usable.shuffled(using: &generator)
        let rowAttribute = shuffled[0]
        let columnAttribute = ruleCount > 1 ? shuffled[1] : nil

        let base = randomFigure(using: &generator)
        let rowValues = distinctValues(of: rowAttribute, count: size, using: &generator)
        let columnValues = columnAttribute.map {
            distinctValues(of: $0, count: size, using: &generator)
        }

        var cells: [LogicFigure?] = []
        for row in 0 ..< size {
            for column in 0 ..< size {
                var figure = base
                figure = apply(rowValues[row], to: figure)
                if let columnValues { figure = apply(columnValues[column], to: figure) }
                if progression {
                    // Count climbs across the row: 1, 2, 3.
                    figure.count = column + 1
                }
                cells.append(figure)
            }
        }

        // The bottom-right cell is always the missing one. Predictability is
        // helpful here — a child should spend attention on the rule, not on
        // hunting for the hole.
        let answer = cells[cells.count - 1]!
        cells[cells.count - 1] = nil

        return LogicPuzzle(
            tier: tier,
            rows: size,
            columns: size,
            cells: cells,
            choices: choices(for: answer, using: &generator),
            answer: answer
        )
    }

    /// The answer plus three near-misses, each differing in exactly one attribute.
    static func choices(
        for answer: LogicFigure,
        using generator: inout some RandomNumberGenerator
    ) -> [LogicFigure] {
        var result = [answer]
        for attribute in FigureAttribute.allCases.shuffled(using: &generator) {
            guard result.count < 4 else { break }
            let candidate = vary(answer, attribute: attribute, using: &generator)
            if !result.contains(candidate) { result.append(candidate) }
        }
        // Top up in the unlikely event two variations collided.
        while result.count < 4 {
            let candidate = randomFigure(using: &generator)
            if !result.contains(candidate) { result.append(candidate) }
        }
        return result.shuffled(using: &generator)
    }

    // MARK: - Attribute plumbing

    /// A concrete value for one attribute, so rules can be applied uniformly.
    enum AttributeValue: Equatable, Sendable {
        case shape(LogicFigure.Shape)
        case color(PackColor)
        case count(Int)
        case size(LogicFigure.Size)
    }

    static func apply(_ value: AttributeValue, to figure: LogicFigure) -> LogicFigure {
        var result = figure
        switch value {
        case .shape(let shape): result.shape = shape
        case .color(let color): result.color = color
        case .count(let count): result.count = count
        case .size(let size): result.size = size
        }
        return result
    }

    private static func distinctValues(
        of attribute: FigureAttribute,
        count: Int,
        using generator: inout some RandomNumberGenerator
    ) -> [AttributeValue] {
        switch attribute {
        case .shape:
            LogicFigure.Shape.allCases.shuffled(using: &generator).prefix(count).map { .shape($0) }
        case .color:
            palette.shuffled(using: &generator).prefix(count).map { .color($0) }
        case .count:
            Array(1 ... 3).shuffled(using: &generator).prefix(count).map { .count($0) }
        case .size:
            LogicFigure.Size.allCases.shuffled(using: &generator).prefix(count).map { .size($0) }
        }
    }

    /// Returns `figure` with one attribute changed to a different value.
    static func vary(
        _ figure: LogicFigure,
        attribute: FigureAttribute,
        using generator: inout some RandomNumberGenerator
    ) -> LogicFigure {
        var result = figure
        switch attribute {
        case .shape:
            result.shape = LogicFigure.Shape.allCases
                .filter { $0 != figure.shape }
                .randomElement(using: &generator) ?? figure.shape
        case .color:
            result.color = palette
                .filter { $0 != figure.color }
                .randomElement(using: &generator) ?? figure.color
        case .count:
            result.count = (1 ... 3)
                .filter { $0 != figure.count }
                .randomElement(using: &generator) ?? figure.count
        case .size:
            result.size = LogicFigure.Size.allCases
                .filter { $0 != figure.size }
                .randomElement(using: &generator) ?? figure.size
        }
        return result
    }

    private static func randomFigure(
        using generator: inout some RandomNumberGenerator
    ) -> LogicFigure {
        LogicFigure(
            shape: LogicFigure.Shape.allCases.randomElement(using: &generator) ?? .circle,
            color: palette.randomElement(using: &generator) ?? .sky,
            count: Int.random(in: 1 ... 3, using: &generator),
            size: LogicFigure.Size.allCases.randomElement(using: &generator) ?? .medium
        )
    }
}
