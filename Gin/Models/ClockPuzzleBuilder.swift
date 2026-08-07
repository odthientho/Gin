import Foundation

/// Difficulty rungs for reading a dial, in the order clocks are actually taught.
enum ClockTier: Int, CaseIterable, Codable, Sendable, Comparable {
    /// The long hand on twelve. Only the short hand carries information.
    case oClock = 1
    /// Adds the long hand on six — the first time it means anything.
    case halfPast
    /// Adds quarter past and quarter to, which is where "to" appears and the
    /// spoken hour stops matching the short hand.
    case quarters
    /// Every five minutes, read off the numerals as fives.
    case fiveMinutes
    /// Any minute at all, which needs the small ticks.
    case anyMinute

    static func < (lhs: ClockTier, rhs: ClockTier) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Minutes this rung is allowed to show.
    var minutes: [Int] {
        switch self {
        case .oClock: [0]
        case .halfPast: [0, 30]
        case .quarters: [0, 15, 30, 45]
        case .fiveMinutes: Array(stride(from: 0, to: 60, by: 5))
        case .anyMinute: Array(0 ..< 60)
        }
    }

    /// Shown in the parent zone, never to the child.
    var parentFacingName: String {
        switch self {
        case .oClock: "O'clock"
        case .halfPast: "Half past"
        case .quarters: "Quarter past and to"
        case .fiveMinutes: "Every five minutes"
        case .anyMinute: "Any minute"
        }
    }
}

/// One clock question.
struct ClockPuzzle: Identifiable, Equatable {
    let id = UUID()
    let tier: ClockTier
    let answer: ClockTime
    /// Includes the answer, already shuffled.
    let choices: [ClockTime]

    static func == (lhs: ClockPuzzle, rhs: ClockPuzzle) -> Bool { lhs.id == rhs.id }
}

/// Generates clock-reading puzzles.
///
/// As with the Logic pack, the wrong answers are the hard part. A child who has
/// not yet learned to read a dial can still guess correctly if the distractors
/// are random times, so every distractor here is a *plausible misreading*:
///
/// - the two hands swapped, which is the classic beginner error
/// - the neighbouring hour, for a short hand read to the wrong side
/// - the same hands read as "past" when they mean "to"
///
/// Those are the mistakes children actually make, so getting it right means
/// having actually read the clock.
enum ClockPuzzleBuilder {

    static let answersToUnlockNextTier = 4

    static func puzzle(
        upTo ceiling: ClockTier,
        using generator: inout some RandomNumberGenerator
    ) -> ClockPuzzle {
        let available = ClockTier.allCases.filter { $0 <= ceiling }
        let tier: ClockTier
        if available.count == 1 || Int.random(in: 0 ..< 100, using: &generator) < 60 {
            tier = ceiling
        } else {
            tier = available.dropLast().randomElement(using: &generator) ?? ceiling
        }
        return puzzle(tier: tier, using: &generator)
    }

    static func puzzle(
        tier: ClockTier,
        using generator: inout some RandomNumberGenerator
    ) -> ClockPuzzle {
        let answer = ClockTime(
            hour: Int.random(in: 1 ... 12, using: &generator),
            minute: tier.minutes.randomElement(using: &generator) ?? 0
        )
        return ClockPuzzle(
            tier: tier,
            answer: answer,
            choices: choices(for: answer, tier: tier, using: &generator)
        )
    }

    /// The answer plus three plausible misreadings.
    static func choices(
        for answer: ClockTime,
        tier: ClockTier,
        using generator: inout some RandomNumberGenerator
    ) -> [ClockTime] {
        var result = [answer]

        func add(_ candidate: ClockTime) {
            guard result.count < 4, !result.contains(candidate) else { return }
            result.append(candidate)
        }

        // Hands swapped: reading the short hand as the long one. Only offered
        // when it lands on a time this rung could legitimately show, or it is
        // recognisable as an impostor.
        let swappedHour = answer.minute == 0 ? 12 : answer.minute / 5
        let swappedMinute = (answer.hour % 12) * 5
        if tier.minutes.contains(swappedMinute) {
            add(ClockTime(hour: swappedHour == 0 ? 12 : swappedHour, minute: swappedMinute))
        }

        // The neighbouring hour, same minutes — a short hand read to the wrong
        // side of the numeral. This is the "quarter to four looks like three"
        // mistake made concrete.
        for offset in [1, -1].shuffled(using: &generator) {
            add(ClockTime(hour: answer.hour + offset, minute: answer.minute))
        }

        // A different minute value from the same rung, hour unchanged.
        for minute in tier.minutes.shuffled(using: &generator) where minute != answer.minute {
            add(ClockTime(hour: answer.hour, minute: minute))
        }

        // Only reachable when a rung has too few distinct minutes to fill four
        // choices — o'clock, where every distractor must be a different hour.
        while result.count < 4 {
            let candidate = ClockTime(
                hour: Int.random(in: 1 ... 12, using: &generator),
                minute: tier.minutes.randomElement(using: &generator) ?? 0
            )
            add(candidate)
        }

        return result.shuffled(using: &generator)
    }
}
