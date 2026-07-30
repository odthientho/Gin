import Foundation

/// How hard the app currently is.
///
/// A level is chosen by the *parent*, behind the parental gate. The child never
/// sees a level picker, is never asked their age, and never gets to change it —
/// they just open the app and everything in it is the right size for them.
///
/// Levels do not swap content out. A `big` child still gets Animals; they get it
/// with four choices instead of three and a larger pool in play. What a level
/// actually does is two things: gate the advanced packs via ``Pack/minLevel``,
/// and supply a ``LevelParams`` to each mechanic.
enum Level: Int, Codable, Sendable, CaseIterable, Comparable, Identifiable {
    case little = 1   // ages 2-3
    case middle = 2   // ages 3-4
    case big    = 3   // ages 4-6

    var id: Int { rawValue }

    /// Shown in the parent zone only. Never rendered where a child can see it.
    var parentFacingName: String {
        switch self {
        case .little: "Little"
        case .middle: "Middle"
        case .big:    "Big"
        }
    }

    var parentFacingAgeRange: String {
        switch self {
        case .little: "2 to 3 years"
        case .middle: "3 to 4 years"
        case .big:    "4 to 6 years"
        }
    }

    static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// How a question is posed.
enum PromptType: String, Codable, Sendable {
    /// "Where is the cow?" — spoken aloud, choices are pictures.
    case audio
    /// A flag fills the screen and the choices are names. The reverse direction
    /// for Flags & Countries; the same mechanic with this one value flipped.
    case visual
}

/// The three graded steps of the Math pack. Objects come before symbols, always.
enum MathStep: Int, Codable, Sendable {
    /// Three apples, then two more. Tap each to count, then tap the numeral.
    case objects = 1
    /// The same apples, with "3" and "2" written beneath each group.
    case bridge = 2
    /// `3 + 2 = ?` alone, with a hint tap that brings the objects back.
    case symbols = 3

    var maxSum: Int {
        switch self {
        case .objects: 5
        case .bridge: 10
        case .symbols: 20
        }
    }
}

/// Everything a mechanic needs to know about how hard to be.
///
/// Mechanics take this rather than a `Level` directly, so difficulty stays a
/// data question and a mechanic never grows a `switch` over age.
struct LevelParams: Sendable, Equatable {
    /// How many options a question offers. Three at the youngest — a fourth
    /// choice measurably increases mis-taps before about three years old.
    var choiceCount: Int
    /// How many items from the pack are in rotation at once.
    var itemPoolSize: Int
    /// Whether a stuck child gets a nudge (the right answer gently pulses).
    var hintsEnabled: Bool
    var promptType: PromptType
    /// The largest quantity Count & Tap will ask a child to count out.
    var maxCountingQuantity: Int
    /// How many pairs Match deals.
    var matchPairs: Int
    /// Whether Match turns the cards face-down after a preview.
    ///
    /// False at the youngest level, which turns Match from a memory game into a
    /// pure *matching* game — recall is a separate skill that arrives later, and
    /// bundling it in makes the mechanic impossible at two.
    var matchHidesCards: Bool
    /// Only consulted by the Math pack.
    var mathStep: MathStep

    static func params(for level: Level) -> LevelParams {
        switch level {
        case .little:
            LevelParams(choiceCount: 3, itemPoolSize: 6, hintsEnabled: true,
                        promptType: .audio, maxCountingQuantity: 5,
                        matchPairs: 3, matchHidesCards: false, mathStep: .objects)
        case .middle:
            LevelParams(choiceCount: 4, itemPoolSize: 10, hintsEnabled: true,
                        promptType: .audio, maxCountingQuantity: 8,
                        matchPairs: 4, matchHidesCards: true, mathStep: .objects)
        case .big:
            LevelParams(choiceCount: 4, itemPoolSize: 16, hintsEnabled: false,
                        promptType: .audio, maxCountingQuantity: 10,
                        matchPairs: 5, matchHidesCards: true, mathStep: .bridge)
        }
    }
}
