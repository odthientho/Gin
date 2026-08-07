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

    /// How the time is read aloud: the hour, then the minutes.
    ///
    /// Deliberately *not* "half past" or "quarter to". Those forms carry two
    /// extra ideas a child has to learn before they can say a time at all —
    /// that fifteen minutes is a "quarter", and that past the half hour English
    /// counts *down* to the next hour, so 3:45 becomes "quarter to four" and the
    /// spoken hour stops matching the hand they are looking at. Reading the two
    /// hands straight off, in the order they appear, is one idea instead of
    /// three, and it is what every digital clock in the house already says.
    ///
    /// Minutes one to nine take "oh", as in "eight oh five" — the natural
    /// spoken form, and it keeps single digits from sounding like the hour.
    var spoken: String {
        switch minute {
        case 0:
            "\(Self.word(hour)) o'clock"
        case 1 ... 9:
            "\(Self.word(hour)) oh \(Self.word(minute))"
        default:
            "\(Self.word(hour)) \(Self.word(minute))"
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
    /// Advances *within* the hour: at three thirty the short hand sits midway
    /// between three and four, not on the three. A clock that parks the hour
    /// hand on the numeral teaches a child to read a clock that does not
    /// exist, and makes three thirty look identical to three o'clock.
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
