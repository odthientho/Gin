import Foundation
import Testing
@testable import Gin

struct ClockTimeTests {

    /// The phrasing table, spelled out. Past half past, English counts down to
    /// the *next* hour — the thing children and clock apps most often get wrong.
    @Test("Times are read the way they are taught")
    func spokenFormsAreCorrect() {
        let cases: [(Int, Int, String)] = [
            (3, 0,  "three o'clock"),
            (12, 0, "twelve o'clock"),
            (3, 15, "quarter past three"),
            (3, 30, "half past three"),
            (3, 45, "quarter to four"),
            (3, 5,  "five past three"),
            (3, 10, "ten past three"),
            (3, 20, "twenty past three"),
            (3, 25, "twenty-five past three"),
            (3, 35, "twenty-five to four"),
            (3, 40, "twenty to four"),
            (3, 50, "ten to four"),
            (3, 55, "five to four"),
            (3, 1,  "one past three"),
            (3, 59, "one to four"),
        ]
        for (hour, minute, expected) in cases {
            #expect(ClockTime(hour: hour, minute: minute).spoken == expected,
                    "\(hour):\(minute) read as '\(ClockTime(hour: hour, minute: minute).spoken)'")
        }
    }

    /// The wrap is the trap: twelve, not zero or thirteen.
    @Test("The hour wraps to twelve, not zero")
    func hourWraps() {
        #expect(ClockTime(hour: 12, minute: 45).spoken == "quarter to one")
        #expect(ClockTime(hour: 12, minute: 45).spokenHour == 1)
        #expect(ClockTime(hour: 11, minute: 50).spoken == "ten to twelve")
        // Out-of-range input is normalised rather than trusted.
        #expect(ClockTime(hour: 13, minute: 0).hour == 1)
        #expect(ClockTime(hour: 0, minute: 0).hour == 12)
        #expect(ClockTime(hour: 3, minute: 60).minute == 0)
    }

    @Test("Digital form is zero-padded")
    func digitalForm() {
        #expect(ClockTime(hour: 3, minute: 5).digital == "3:05")
        #expect(ClockTime(hour: 12, minute: 0).digital == "12:00")
        #expect(ClockTime(hour: 9, minute: 45).digital == "9:45")
    }

    /// A clock that parks the hour hand on the numeral teaches a dial that does
    /// not exist — and makes half past three look identical to three o'clock.
    @Test("The hour hand advances within the hour")
    func hourHandCreeps() {
        #expect(ClockTime(hour: 3, minute: 0).hourAngle == 90)
        #expect(ClockTime(hour: 3, minute: 30).hourAngle == 105)
        #expect(ClockTime(hour: 3, minute: 59).hourAngle > 104)
        #expect(ClockTime(hour: 12, minute: 0).hourAngle == 0)
        // Half past three must not look like three.
        #expect(ClockTime(hour: 3, minute: 30).hourAngle != ClockTime(hour: 3, minute: 0).hourAngle)
    }

    @Test("The minute hand sweeps six degrees a minute")
    func minuteHandSweeps() {
        #expect(ClockTime(hour: 1, minute: 0).minuteAngle == 0)
        #expect(ClockTime(hour: 1, minute: 15).minuteAngle == 90)
        #expect(ClockTime(hour: 1, minute: 30).minuteAngle == 180)
        #expect(ClockTime(hour: 1, minute: 45).minuteAngle == 270)
    }

    @Test("Minute words go all the way to fifty-nine")
    func minuteWords() {
        #expect(ClockTime.word(1) == "one")
        #expect(ClockTime.word(15) == "fifteen")
        #expect(ClockTime.word(20) == "twenty")
        #expect(ClockTime.word(25) == "twenty-five")
        #expect(ClockTime.word(30) == "thirty")
        #expect(ClockTime.word(59) == "fifty-nine")
    }
}

struct ClockPuzzleBuilderTests {

    @Test("Every rung only shows the minutes it teaches")
    func rungsRespectTheirMinutes() {
        for tier in ClockTier.allCases {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = ClockPuzzleBuilder.puzzle(tier: tier, using: &generator)
                #expect(tier.minutes.contains(puzzle.answer.minute),
                        "\(tier) produced :\(puzzle.answer.minute)")
            }
        }
    }

    @Test("The ladder follows how clocks are taught")
    func ladderIsOrdered() {
        #expect(ClockTier.allCases.map(\.minutes.count) == [1, 2, 4, 12, 60])
        #expect(ClockTier.oClock.minutes == [0])
        #expect(ClockTier.halfPast.minutes == [0, 30])
        #expect(ClockTier.quarters.minutes == [0, 15, 30, 45])
    }

    @Test("The answer is offered, and the choices are distinct")
    func choicesAreUsable() {
        for tier in ClockTier.allCases {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = ClockPuzzleBuilder.puzzle(tier: tier, using: &generator)
                #expect(puzzle.choices.contains(puzzle.answer), "\(tier) seed \(seed)")
                #expect(Set(puzzle.choices).count == 4, "\(tier) seed \(seed)")
            }
        }
    }

    /// Two different times must never read aloud the same, or the child is asked
    /// to pick between two identical-sounding answers.
    @Test("No two choices read aloud identically")
    func choicesSoundDifferent() {
        for tier in ClockTier.allCases {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = ClockPuzzleBuilder.puzzle(tier: tier, using: &generator)
                let spoken = puzzle.choices.map(\.spoken)
                #expect(Set(spoken).count == spoken.count,
                        "\(tier) seed \(seed): \(spoken)")
            }
        }
    }

    /// Guessing should not work. Every distractor is a time a child could
    /// plausibly misread the dial as, not a random hour.
    @Test("Distractors are plausible misreadings, not noise")
    func distractorsArePlausible() {
        for tier in ClockTier.allCases {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = ClockPuzzleBuilder.puzzle(tier: tier, using: &generator)
                let answer = puzzle.answer

                // Reading the short hand as the long one and vice versa. The
                // classic beginner error, and the distractor that matters most.
                let swappedHour = answer.minute == 0 ? 12 : answer.minute / 5
                let handsSwapped = ClockTime(
                    hour: swappedHour == 0 ? 12 : swappedHour,
                    minute: (answer.hour % 12) * 5
                )

                for wrong in puzzle.choices where wrong != answer {
                    let sameHour = wrong.hour == answer.hour
                    let neighbouringHour =
                        wrong.hour == (answer.hour % 12) + 1 ||
                        answer.hour == (wrong.hour % 12) + 1
                    let sameMinute = wrong.minute == answer.minute
                    // The o'clock rung is the one case where every distractor
                    // must be some other hour, since there is only one minute.
                    let plausible = sameHour || neighbouringHour || sameMinute
                        || wrong == handsSwapped || tier == .oClock
                    #expect(plausible,
                            "\(tier) seed \(seed): \(answer.digital) vs \(wrong.digital)")
                }
            }
        }
    }

    @Test("Puzzles never exceed the rung reached")
    func ceilingIsRespected() {
        for ceiling in ClockTier.allCases {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                #expect(ClockPuzzleBuilder.puzzle(upTo: ceiling, using: &generator).tier <= ceiling)
            }
        }
    }

    @Test("Easier rungs stay in circulation")
    func easierRungsStillAppear() {
        var seen: Set<ClockTier> = []
        for seed in UInt64(1) ... 400 {
            var generator = SeededGenerator(seed: seed)
            seen.insert(ClockPuzzleBuilder.puzzle(upTo: .anyMinute, using: &generator).tier)
        }
        #expect(seen.contains(.anyMinute))
        #expect(seen.contains(.oClock))
    }
}

struct ClockPackTests {

    @Test("The Clock pack has a sticker per rung and both directions")
    func packMatchesLadder() throws {
        let pack = try ContentLoader.load("clock", from: .main)
        #expect(pack.items.count == ClockTier.allCases.count)
        #expect(pack.mechanics == [.clockRead, .clockFind])
        #expect(pack.color == .sun)
        // Reading a dial is a school-age skill; it has no business on a
        // two-year-old's home screen.
        #expect(pack.minLevel == .big)
    }
}

@MainActor
struct ClockProgressTests {

    /// Clock and Logic share the ladder mechanism but must not share a rung.
    @Test("Each pack keeps its own rung")
    func tiersArePerPack() {
        let store = ProgressStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("gin-test-\(UUID().uuidString).json"))

        store.setTier(4, for: "logic")
        #expect(store.tier(for: "logic") == 4)
        #expect(store.tier(for: "clock") == 1, "clock inherited logic's rung")

        store.setTier(2, for: "clock")
        #expect(store.tier(for: "logic") == 4)
        #expect(store.tier(for: "clock") == 2)
    }
}
