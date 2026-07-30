import Foundation

/// One "Where is the cow?" question.
struct FindItQuestion: Equatable, Identifiable {
    let id = UUID()
    let target: Item
    /// Includes the target, already shuffled.
    let choices: [Item]

    static func == (lhs: FindItQuestion, rhs: FindItQuestion) -> Bool { lhs.id == rhs.id }
}

/// One "can you count the ducks?" task.
struct CountingTask: Equatable, Identifiable {
    let id = UUID()
    let item: Item
    let quantity: Int

    static func == (lhs: CountingTask, rhs: CountingTask) -> Bool { lhs.id == rhs.id }
}

/// One arithmetic problem, expressed as objects before it is ever expressed as
/// symbols.
struct MathProblem: Equatable, Identifiable {
    enum Operation: String, Equatable {
        case add, subtract

        var symbol: String { self == .add ? "+" : "−" }
        /// Spoken, not read. "Take away" beats "minus" by years.
        var spokenName: String { self == .add ? "and" : "take away" }
    }

    let id = UUID()
    let operation: Operation
    let left: Int
    let right: Int
    /// What the objects are — apples, ducks, balls.
    let item: Item
    /// Includes the answer, already shuffled.
    let choices: [Int]

    var answer: Int { operation == .add ? left + right : left - right }

    static func == (lhs: MathProblem, rhs: MathProblem) -> Bool { lhs.id == rhs.id }
}

/// One "what comes next?" sequence.
struct PatternTask: Equatable, Identifiable {
    let id = UUID()
    /// The visible run. The answer is what would come after it.
    let sequence: [Item]
    let answer: Item
    /// Includes the answer, already shuffled.
    let choices: [Item]

    static func == (lhs: PatternTask, rhs: PatternTask) -> Bool { lhs.id == rhs.id }
}

/// Builds the questions a round is made of.
///
/// Pulled out of the views so it can be tested directly: the invariants that
/// matter here (the answer is always present, distractors are never duplicated,
/// the same target doesn't repeat back-to-back) are exactly the ones that are
/// invisible when they break and infuriating for a child.
enum RoundBuilder {

    /// Turns in a round, for every mechanic.
    ///
    /// Deliberately one number rather than a per-mechanic tuning. A round used to
    /// be three or four so the sticker arrived before a toddler's attention ran
    /// out — but a round no longer *ends* play, it hands off to a different game.
    /// Ten turns is long enough to settle into a game and short enough that the
    /// next one arrives before it goes stale.
    static let roundLength = 10

    static let questionsPerRound = roundLength
    static let countingTasksPerRound = roundLength
    static let dropInTasksPerRound = roundLength
    static let mathProblemsPerRound = roundLength
    static let patternsPerRound = roundLength
    /// Match counts *pairs*, not cleared boards, so a round is the same length
    /// of effort as everywhere else regardless of how big a board happens to be.
    static let matchPairsPerRound = roundLength

    /// The repeating motifs Patterns uses, easiest first. Expressed as token
    /// indices: `[0, 0, 1]` is AAB.
    ///
    /// Deliberately stops at three distinct tokens. A four-token motif is not
    /// harder in an interesting way — it just exceeds what a child can hold in
    /// view long enough to spot the repeat.
    static let patternMotifs: [[Int]] = [
        [0, 1],        // AB
        [0, 0, 1],     // AAB
        [0, 1, 1],     // ABB
        [0, 1, 2]      // ABC
    ]

    /// - Parameter preferring: when non-empty, the target comes from these ids.
    ///   Grouped packs pass the not-yet-mastered items of the current learning
    ///   group, so questions concentrate on what still needs proving instead of
    ///   re-asking flags the child already knows. Distractors still come from
    ///   the whole pool.
    static func findItQuestion(
        from pool: [Item],
        choiceCount: Int,
        avoiding recentTargetID: Item.ID? = nil,
        preferring preferredIDs: Set<Item.ID> = [],
        using generator: inout some RandomNumberGenerator
    ) -> FindItQuestion? {
        guard pool.count >= 2 else { return nil }

        let preferred = pool.filter { preferredIDs.contains($0.id) }
        let targetPool = preferred.isEmpty ? pool : preferred

        // Don't ask for the same thing twice running unless the pool is so small
        // there is no alternative.
        let targetCandidates = targetPool.filter { $0.id != recentTargetID }
        let searchSpace = targetCandidates.isEmpty ? targetPool : targetCandidates
        guard let target = searchSpace.randomElement(using: &generator) else { return nil }

        let distractors = pool
            .filter { $0.id != target.id }
            .shuffled(using: &generator)
            .prefix(max(0, choiceCount - 1))

        let choices = ([target] + distractors).shuffled(using: &generator)
        return FindItQuestion(target: target, choices: choices)
    }

    /// Builds an addition or subtraction problem sized to the child's step.
    ///
    /// Two invariants that matter: the answer is never negative (a toddler has no
    /// model for that), and both operands are at least one, because "three and
    /// none" teaches nothing and reads as a broken question.
    static func mathProblem(
        from pool: [Item],
        step: MathStep,
        allowSubtraction: Bool = true,
        using generator: inout some RandomNumberGenerator
    ) -> MathProblem? {
        guard let item = pool.randomElement(using: &generator) else { return nil }

        let operation: MathProblem.Operation =
            allowSubtraction && Bool.random(using: &generator) ? .subtract : .add

        let left: Int
        let right: Int

        switch operation {
        case .add:
            // Keep the sum inside the step's range.
            left = Int.random(in: 1 ... max(1, step.maxSum - 1), using: &generator)
            right = Int.random(in: 1 ... max(1, step.maxSum - left), using: &generator)
        case .subtract:
            left = Int.random(in: 2 ... max(2, step.maxSum), using: &generator)
            right = Int.random(in: 1 ... (left - 1), using: &generator)
        }

        let answer = operation == .add ? left + right : left - right
        return MathProblem(
            operation: operation,
            left: left,
            right: right,
            item: item,
            choices: numberChoices(around: answer, step: step, using: &generator)
        )
    }

    /// Distractors that sit near the answer, so the choice is a real judgement
    /// rather than one plausible number beside two absurd ones.
    private static func numberChoices(
        around answer: Int,
        step: MathStep,
        using generator: inout some RandomNumberGenerator
    ) -> [Int] {
        var options: Set<Int> = [answer]
        var offset = 1

        while options.count < 3, offset <= step.maxSum {
            for candidate in [answer - offset, answer + offset] where candidate >= 0 {
                guard options.count < 3, candidate <= step.maxSum else { continue }
                options.insert(candidate)
            }
            offset += 1
        }

        return options.shuffled(using: &generator)
    }

    /// Builds a repeating sequence with the next element withheld.
    ///
    /// The visible run is always long enough to contain the motif **at least
    /// twice** — one repetition is not a pattern, it is just a row of things, and
    /// a child cannot infer a rule from a single instance.
    ///
    /// Distractors come from the motif's own tokens wherever possible, so a wrong
    /// answer is a plausible misreading of the rule rather than an obviously
    /// foreign shape.
    static func patternTask(
        from pool: [Item],
        using generator: inout some RandomNumberGenerator
    ) -> PatternTask? {
        guard pool.count >= 3, let motif = patternMotifs.randomElement(using: &generator)
        else { return nil }

        let distinctTokens = (motif.max() ?? 0) + 1
        guard pool.count >= distinctTokens else { return nil }

        let tokens = Array(pool.shuffled(using: &generator).prefix(distinctTokens))
        let visibleLength = motif.count * 2

        func element(at index: Int) -> Item { tokens[motif[index % motif.count]] }

        let sequence = (0 ..< visibleLength).map(element)
        let answer = element(at: visibleLength)

        var choices: [Item] = [answer]
        // Prefer the motif's own tokens as distractors...
        for token in tokens.shuffled(using: &generator)
        where choices.count < 3 && !choices.contains(where: { $0.id == token.id }) {
            choices.append(token)
        }
        // ...and only reach into the wider pool if the motif was too small.
        for item in pool.shuffled(using: &generator)
        where choices.count < 3 && !choices.contains(where: { $0.id == item.id }) {
            choices.append(item)
        }

        return PatternTask(
            sequence: sequence,
            answer: answer,
            choices: choices.shuffled(using: &generator)
        )
    }

    static func countingTask(
        from pool: [Item],
        maxQuantity: Int,
        avoiding recentItemID: Item.ID? = nil,
        using generator: inout some RandomNumberGenerator
    ) -> CountingTask? {
        guard !pool.isEmpty, maxQuantity >= 1 else { return nil }

        let candidates = pool.filter { $0.id != recentItemID }
        let searchSpace = candidates.isEmpty ? pool : candidates
        guard let item = searchSpace.randomElement(using: &generator) else { return nil }

        // Never zero. "Count no ducks" is not a thing a toddler can act on.
        let quantity = Int.random(in: 1 ... maxQuantity, using: &generator)
        return CountingTask(item: item, quantity: quantity)
    }
}
