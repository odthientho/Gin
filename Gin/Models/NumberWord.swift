import Foundation

/// Spoken forms of the small numbers.
///
/// Counting is said aloud, not read, so the app needs the *word* rather than the
/// numeral. Hard-coded to ten because that is the whole range Gin ever counts in —
/// a formatter would be more general and less predictable, and predictability is
/// what lets these be swapped for recorded clips later.
enum NumberWord {
    private static let words = [
        "zero", "one", "two", "three", "four", "five",
        "six", "seven", "eight", "nine", "ten"
    ]

    static func spoken(_ value: Int) -> String {
        guard value >= 0, value < words.count else { return String(value) }
        return words[value]
    }

    /// The clip filename for a recorded count, once recordings exist.
    static func clipName(_ value: Int) -> String { "count_\(spoken(value))" }
}
