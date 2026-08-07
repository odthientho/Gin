import Foundation

/// Difficulty rungs for reading a dial.
///
/// The minute hand only ever points at 12, 3, 6 or 9 — the four positions a
/// child can name by looking rather than by counting round the face. Reading
/// to the minute is a later skill and a different one, and putting it on the
/// same ladder would mean the top of the ladder is where the pack stops being
/// usable.
enum ClockTier: Int, CaseIterable, Codable, Sendable, Comparable {
    /// The long hand on twelve. Only the short hand carries information.
    case oClock = 1
    /// Adds the long hand on six — the first time it means anything.
    case thirty
    /// Adds fifteen and forty-five — the long hand on the 3 and the 9, which is
    /// the first time it points somewhere that is not straight up or down.
    case quarters

    static func < (lhs: ClockTier, rhs: ClockTier) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Minutes this rung is allowed to show.
    var minutes: [Int] {
        switch self {
        case .oClock: [0]
        case .thirty: [0, 30]
        case .quarters: [0, 15, 30, 45]
        }
    }

    /// Shown in the parent zone, never to the child.
    var parentFacingName: String {
        switch self {
        case .oClock: "O'clock"
        case .thirty: "Thirty"
        case .quarters: "Fifteen and forty-five"
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
/// - a different minute value from the same rung, hour unchanged
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
        // side of the numeral: a long hand near the 9 drags the eye to the
        // previous hour, so 3:45 gets read as 4:45 or the other way about.
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
