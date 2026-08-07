import Foundation

/// A time on a twelve-hour clock face.
///
/// No AM/PM. A child learning to read a dial is learning where the hands point,
/// and half the day is a separate idea that only muddies it.
struct ClockTime: Equatable, Hashable, Sendable {
    /// 1...12 as it appears on the dial.
    var hour: Int
    /// 0...59.
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = ((hour - 1) % 12 + 12) % 12 + 1
        self.minute = ((minute % 60) + 60) % 60
    }

    /// The hour that gets *said*, which is not always the hour the short hand
    /// is nearest.
    ///
    /// Past half past, English counts down to the next hour: 3:45 is "quarter to
    /// four", not "quarter to three". This is the single thing children — and
    /// clock apps — most often get wrong, so it lives in one place.
    var spokenHour: Int {
        minute > 30 ? (hour % 12) + 1 : hour
    }

    /// How the time is read aloud.
    var spoken: String {
        switch minute {
        case 0:  "\(Self.word(hour)) o'clock"
        case 15: "quarter past \(Self.word(hour))"
        case 30: "half past \(Self.word(hour))"
        case 45: "quarter to \(Self.word(spokenHour))"
        case let m where m < 30:
            "\(Self.word(m)) past \(Self.word(hour))"
        default:
            "\(Self.word(60 - minute)) to \(Self.word(spokenHour))"
        }
    }

    /// The digital form, for the child who can already read numerals.
    var digital: String {
        String(format: "%d:%02d", hour, minute)
    }

    // MARK: - Hand geometry

    /// Degrees clockwise from twelve for the minute hand.
    var minuteAngle: Double { Double(minute) * 6 }

    /// Degrees clockwise from twelve for the hour hand.
    ///
    /// Advances *within* the hour: at half past three the short hand sits
    /// midway between three and four, not on the three. A clock that parks the
    /// hour hand on the numeral teaches a child to read a clock that does not
    /// exist, and makes "half past three" look like "three".
    var hourAngle: Double {
        (Double(hour % 12) + Double(minute) / 60) * 30
    }

    // MARK: - Words

    private static let ones = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
        "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
        "sixteen", "seventeen", "eighteen", "nineteen"
    ]

    /// Spells a number up to 59 — enough for any minute on a dial.
    static func word(_ value: Int) -> String {
        if value < 20 { return ones[max(0, value)] }
        let tens = ["", "", "twenty", "thirty", "forty", "fifty"][value / 10]
        let unit = value % 10
        return unit == 0 ? tens : "\(tens)-\(ones[unit])"
    }
}
