import Foundation
import SwiftUI
import Testing
@testable import Gin

private func countableItems(_ count: Int = 4) -> [Item] {
    (0 ..< count).map { index in
        Item(
            id: "obj\(index)",
            name: "Apple",
            art: Art(kind: .emoji, value: "🍎"),
            voiceClip: "apple"
        )
    }
}

struct MathProblemTests {

    @Test("An answer is never negative")
    func answersAreNeverNegative() {
        for seed in UInt64(1) ... 200 {
            for step in [MathStep.objects, .bridge, .symbols] {
                var generator = SeededGenerator(seed: seed)
                guard let problem = RoundBuilder.mathProblem(
                    from: countableItems(), step: step, using: &generator
                ) else { continue }
                #expect(problem.answer >= 0,
                        "\(problem.left) \(problem.operation.symbol) \(problem.right)")
            }
        }
    }

    @Test("Both operands are at least one")
    func operandsAreNeverZero() {
        for seed in UInt64(1) ... 200 {
            var generator = SeededGenerator(seed: seed)
            guard let problem = RoundBuilder.mathProblem(
                from: countableItems(), step: .bridge, using: &generator
            ) else { continue }
            #expect(problem.left >= 1)
            #expect(problem.right >= 1)
        }
    }

    @Test("A sum stays inside the step's range")
    func sumsRespectTheStep() {
        for seed in UInt64(1) ... 200 {
            for step in [MathStep.objects, .bridge, .symbols] {
                var generator = SeededGenerator(seed: seed)
                guard let problem = RoundBuilder.mathProblem(
                    from: countableItems(), step: step, using: &generator
                ) else { continue }
                #expect(problem.answer <= step.maxSum)
                #expect(problem.left <= step.maxSum)
            }
        }
    }

    @Test("Subtraction never asks for more than there is")
    func subtractionIsPossible() {
        for seed in UInt64(1) ... 300 {
            var generator = SeededGenerator(seed: seed)
            guard let problem = RoundBuilder.mathProblem(
                from: countableItems(), step: .symbols, using: &generator
            ), problem.operation == .subtract else { continue }
            #expect(problem.right < problem.left)
        }
    }

    @Test("The answer is always offered, with unique distractors")
    func choicesAreUsable() {
        for seed in UInt64(1) ... 200 {
            var generator = SeededGenerator(seed: seed)
            guard let problem = RoundBuilder.mathProblem(
                from: countableItems(), step: .bridge, using: &generator
            ) else { continue }
            #expect(problem.choices.contains(problem.answer))
            #expect(Set(problem.choices).count == problem.choices.count)
            #expect(problem.choices.allSatisfy { $0 >= 0 })
        }
    }

    @Test("Addition can be requested on its own")
    func additionOnlyIsPossible() {
        for seed in UInt64(1) ... 100 {
            var generator = SeededGenerator(seed: seed)
            guard let problem = RoundBuilder.mathProblem(
                from: countableItems(), step: .objects,
                allowSubtraction: false, using: &generator
            ) else { continue }
            #expect(problem.operation == .add)
        }
    }
}

struct PackIdentityTests {

    /// Color is how a pre-reader recognizes a category before they can read its
    /// name. Unique-per-category was the original rule and it does not survive
    /// eleven categories — there are not eleven hues a three-year-old can tell
    /// apart. So color became a *family* cue: at most two packs per hue, from
    /// related domains, with unmistakably different icons.
    ///
    /// The ceiling is what this guards. Three packs on one hue means color has
    /// stopped carrying information, which is how two sky-blue packs shipped once.
    @Test("At most two packs share any one color")
    func packColorsFormSmallFamilies() throws {
        let packs = try ContentLoader.loadAll(from: .main)
        let byColor = Dictionary(grouping: packs, by: \.color)

        for (color, sharing) in byColor {
            let ids = sharing.map(\.id).joined(separator: ", ")
            #expect(
                sharing.count <= 2,
                "\(color.rawValue) is used by \(sharing.count) packs: \(ids)"
            )
        }
    }

    /// Two packs sharing a hue rely entirely on their icons to be told apart, so
    /// an accidental duplicate icon would make them genuinely indistinguishable.
    @Test("No two packs share an icon")
    func packIconsAreUnique() throws {
        let icons = try ContentLoader.loadAll(from: .main).map(\.icon)
        #expect(Set(icons).count == icons.count)
    }

    /// The home screen never scrolls, so every pack available at a level plus the
    /// sticker album has to fit one landscape screen at no worse than three rows.
    @Test("Every level's home screen fits without scrolling")
    func homeGridAlwaysFits() throws {
        let packs = try ContentLoader.loadAll(from: .main)

        for level in Level.allCases {
            let tileCount = packs.filter { $0.isAvailable(at: level) }.count + 1
            let columns = GridFit.columnCount(for: tileCount)
            let rows = GridFit.rows(count: tileCount, columns: columns)
            #expect(rows <= 3, "\(level.parentFacingName): \(tileCount) tiles needed \(rows) rows")
        }
    }

    @Test("Pack ids are unique")
    func packIDsAreUnique() throws {
        let ids = try ContentLoader.loadAll(from: .main).map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Every pack declares at least one buildable mechanic")
    func packsHaveMechanics() throws {
        for pack in try ContentLoader.loadAll(from: .main) {
            #expect(!pack.mechanics.isEmpty, "\(pack.id) declares no mechanics")
        }
    }
}

struct PatternTaskTests {

    private func tokens(_ count: Int = 5) -> [Item] {
        (0 ..< count).map { index in
            Item(
                id: "tok\(index)",
                name: "Token \(index)",
                art: Art(kind: .geometry, value: "swatch:#FF0000"),
                voiceClip: "tok\(index)"
            )
        }
    }

    @Test("The visible run always shows the motif at least twice")
    func motifRepeatsAtLeastTwice() {
        for seed in UInt64(1) ... 200 {
            var generator = SeededGenerator(seed: seed)
            guard let task = RoundBuilder.patternTask(from: tokens(), using: &generator)
            else { continue }
            // Shortest motif is AB, so the shortest legal run is 4.
            #expect(task.sequence.count >= 4)
            #expect(task.sequence.count.isMultiple(of: 2) || task.sequence.count % 3 == 0)
        }
    }

    @Test("The answer genuinely continues the sequence")
    func answerContinuesThePattern() {
        for seed in UInt64(1) ... 200 {
            var generator = SeededGenerator(seed: seed)
            guard let task = RoundBuilder.patternTask(from: tokens(), using: &generator)
            else { continue }

            // The run is the motif twice, so the next element must equal the one
            // a full motif-length earlier.
            let period = task.sequence.count / 2
            let expected = task.sequence[task.sequence.count - period]
            #expect(task.answer.id == expected.id)
        }
    }

    @Test("The answer is offered, and choices are distinct")
    func choicesAreUsable() {
        for seed in UInt64(1) ... 200 {
            var generator = SeededGenerator(seed: seed)
            guard let task = RoundBuilder.patternTask(from: tokens(), using: &generator)
            else { continue }
            #expect(task.choices.contains { $0.id == task.answer.id })
            #expect(Set(task.choices.map(\.id)).count == task.choices.count)
            #expect(task.choices.count == 3)
        }
    }

    @Test("A pool too small for a pattern produces nothing")
    func refusesTinyPool() {
        var generator = SeededGenerator(seed: 5)
        #expect(RoundBuilder.patternTask(from: tokens(2), using: &generator) == nil)
    }

    @Test("The patterns pack is playable with its own tokens")
    func patternsPackWorks() throws {
        let pack = try ContentLoader.load("patterns", from: .main)
        #expect(pack.mechanics == [.pattern])
        #expect(pack.minLevel == .big)

        var generator = SeededGenerator(seed: 11)
        let task = RoundBuilder.patternTask(
            from: pack.items(for: .params(for: .big)),
            using: &generator
        )
        #expect(task != nil)
    }
}

struct MiddleLevelContentTests {

    @Test("Letters covers the whole uppercase alphabet as geometry")
    func lettersAreComplete() throws {
        let pack = try ContentLoader.load("letters", from: .main)
        #expect(pack.items.count == 26)
        #expect(pack.minLevel == .middle)
        #expect(pack.items.allSatisfy { $0.art.kind == .geometry })
        #expect(pack.items.first?.art.value == "letter:A")
        #expect(pack.items.last?.art.value == "letter:Z")
    }

    @Test("Opposites ships complete pairs")
    func oppositesArePaired() throws {
        let pack = try ContentLoader.load("opposites", from: .main)
        // Every tag groups exactly one pair; a lone half would make "find the
        // opposite" unanswerable.
        let byTag = Dictionary(grouping: pack.items) { $0.tags.first ?? "" }
        for (tag, items) in byTag {
            #expect(items.count == 2, "\(tag) has \(items.count) items, expected a pair")
        }
    }

    @Test("Middle level actually adds categories")
    func middleAddsContent() throws {
        let packs = try ContentLoader.loadAll(from: .main)
        let atLittle = packs.filter { $0.isAvailable(at: .little) }.count
        let atMiddle = packs.filter { $0.isAvailable(at: .middle) }.count
        let atBig = packs.filter { $0.isAvailable(at: .big) }.count

        #expect(atMiddle > atLittle, "Middle offered no new categories over Little")
        #expect(atBig > atMiddle, "Big offered no new categories over Middle")
    }
}

struct FlagContentTests {

    @Test("The flags pack carries all 195 countries")
    func flagsDecode() throws {
        let pack = try ContentLoader.load("flags", from: .main)
        #expect(pack.minLevel == .big)
        #expect(pack.items.count == 195)
        #expect(Set(pack.items.map(\.id)).count == 195)
        // No Discover: a no-scroll grid cannot hold 195 tiles.
        #expect(!pack.mechanics.contains(.discover))
        // Learning comes before testing: the deck is first, so it is what the
        // pack opens into.
        #expect(pack.mechanics.first == .flashcard)
    }

    @Test("The deck runs familiar flags first")
    func rankingOrderIsApplied() throws {
        let items = try ContentLoader.load("flags", from: .main).items
        #expect(items[0].name == "France")
        #expect(items[1].name == "Spain")
        #expect(items[2].name == "United States")
        // Spot-checks deeper in: rank 24 and rank 39 in the supplied list.
        #expect(items[23].name == "Vietnam")
        #expect(items[38].name == "Brazil")
        // The unranked handful goes last, not lost.
        #expect(items.count == 195)
    }

    @Test("Every flag is a valid, unique emoji flag")
    func flagsAreEmojiFlags() throws {
        let pack = try ContentLoader.load("flags", from: .main)
        let indicatorRange = UnicodeScalar(0x1F1E6)! ... UnicodeScalar(0x1F1FF)!

        for item in pack.items {
            #expect(item.art.kind == .emoji, "\(item.id) is not emoji art")
            let scalars = Array(item.art.value.unicodeScalars)
            // A flag emoji is exactly two regional-indicator characters; anything
            // else renders as floating letters instead of a flag.
            #expect(scalars.count == 2, "\(item.id): \(scalars.count) scalars")
            #expect(scalars.allSatisfy { indicatorRange.contains($0) },
                    "\(item.id) is not made of regional indicators")
        }
        #expect(Set(pack.items.map(\.art.value)).count == 195, "duplicate flag emoji")
    }

    /// The 20 countries from the original hand-built pack must keep their ids —
    /// stickers were earned under them, and a changed id orphans the sticker.
    @Test("Original flag ids survive the switch to the full country list")
    func originalIdsAreStable() throws {
        let ids = Set(try ContentLoader.load("flags", from: .main).items.map(\.id))
        let original = [
            "vietnam", "japan", "france", "italy", "germany", "netherlands",
            "belgium", "ireland", "sweden", "denmark", "switzerland", "poland",
            "ukraine", "austria", "indonesia", "thailand", "nigeria",
            "argentina", "canada", "brazil"
        ]
        for id in original {
            #expect(ids.contains(id), "\(id) went missing")
        }
    }

    @Test("Every mechanic runs the same ten-turn round")
    func roundsAreTenTurns() {
        #expect(RoundBuilder.roundLength == 10)
        // One number, not six drifting ones — a round means the same amount of
        // effort whichever game the child is in.
        #expect(RoundBuilder.questionsPerRound == 10)
        #expect(RoundBuilder.countingTasksPerRound == 10)
        #expect(RoundBuilder.dropInTasksPerRound == 10)
        #expect(RoundBuilder.mathProblemsPerRound == 10)
        #expect(RoundBuilder.patternsPerRound == 10)
        #expect(RoundBuilder.matchPairsPerRound == 10)
    }

    /// A round handing off to the next game only works if the pack has somewhere
    /// to hand off to. Two packs deliberately do not and simply carry on, which
    /// is the correct behaviour rather than an oversight — but a *new* pack
    /// shipping with a single game is almost certainly an accident, so it fails.
    @Test("Every pack either rotates games or is a known single-game pack")
    func packsCanRotateOrAreKnownSingletons() throws {
        let implemented: Set<Mechanic> = [
            .discover, .findIt, .match, .dropIn, .count, .hearIt,
            .addTakeAway, .pattern, .trace, .flashcard
        ]
        // Writing is one long tracing deck; Patterns is a single sequencing game.
        let knownSingletons: Set<String> = ["writing", "patterns", "logic", "comparison"]

        for pack in try ContentLoader.loadAll(from: .main) {
            // Flashcards are study, not a game, so they cannot be the handoff.
            let games = pack.mechanics.filter { implemented.contains($0) && $0 != .flashcard }
            guard !games.isEmpty else { continue }

            if knownSingletons.contains(pack.id) {
                #expect(games.count == 1, "\(pack.id) gained a game; drop it from the exempt list")
            } else {
                #expect(games.count > 1, "\(pack.id) has nowhere to hand off to")
            }
        }
    }

    @Test("Flags is learned 25 countries at a time")
    func learningGroupsAreApplied() throws {
        let pack = try ContentLoader.load("flags", from: .main)
        let params = LevelParams.params(for: .big)
        let groups = pack.learningGroups(for: params)

        #expect(groups.count == 8)
        #expect(groups.dropLast().allSatisfy { $0.count == 25 })
        #expect(groups.last?.count == 20)

        // Nothing mastered: the deck is the first 25, rank 1 through rank 25.
        let firstGroup = pack.currentGroup(mastered: [], for: params)
        #expect(firstGroup.count == 25)
        #expect(firstGroup.first?.name == "France")
        #expect(firstGroup.last?.name == "Switzerland")
        #expect(pack.unlockedItems(mastered: [], for: params).count == 25)

        // 24 of 25 proven: still repeating the first group.
        let almost = Set(firstGroup.dropLast().map(\.id))
        #expect(pack.currentGroup(mastered: almost, for: params).first?.name == "France")

        // All 25 proven: the second group arrives and the window widens to 50.
        let done = Set(firstGroup.map(\.id))
        let secondGroup = pack.currentGroup(mastered: done, for: params)
        #expect(secondGroup.first?.name == "Indonesia")
        #expect(pack.unlockedItems(mastered: done, for: params).count == 50)

        // Everything proven: the last group stays, nothing runs out.
        let all = Set(pack.items.map(\.id))
        #expect(pack.currentGroup(mastered: all, for: params).count == 20)
        #expect(pack.unlockedItems(mastered: all, for: params).count == 195)

        // A pack without a group size is one group, exactly as before.
        let animals = try ContentLoader.load("animals", from: .main)
        let littleParams = LevelParams.params(for: .little)
        #expect(animals.learningGroups(for: littleParams).count == 1)
        #expect(animals.currentGroup(mastered: [], for: littleParams).count
                == animals.items(for: littleParams).count)
    }

    @Test("Questions aim at what still needs proving")
    func preferredTargetsAreChosen() throws {
        let pack = try ContentLoader.load("flags", from: .main)
        let pool = pack.items(for: .params(for: .big))
        let preferred: Set<Item.ID> = ["vietnam", "japan", "canada"]

        for seed in UInt64(1) ... 60 {
            var generator = SeededGenerator(seed: seed)
            let question = try #require(RoundBuilder.findItQuestion(
                from: pool, choiceCount: 4, preferring: preferred, using: &generator
            ))
            #expect(preferred.contains(question.target.id),
                    "target \(question.target.id) ignored the preferred set")
        }

        // An empty preferred set changes nothing.
        var generator = SeededGenerator(seed: 7)
        #expect(RoundBuilder.findItQuestion(
            from: pool, choiceCount: 4, preferring: [], using: &generator
        ) != nil)
    }

    @Test("The pool override keeps every country in rotation")
    func poolOverrideIsHonored() throws {
        let pack = try ContentLoader.load("flags", from: .main)
        // The Big-level cap is 16; flags must ignore it or 179 countries would
        // silently never appear.
        #expect(pack.items(for: .params(for: .big)).count == 195)
        // And a pack without the override still gets capped.
        let animals = try ContentLoader.load("animals", from: .main)
        #expect(animals.items(for: .params(for: .little)).count <= 6)
    }

    @Test("Only the flags pack claims the visual prompt direction")
    func visualPromptIsFlagsOnly() throws {
        #expect(try ContentLoader.load("flags", from: .main).supportsVisualPrompt)
        #expect(try !ContentLoader.load("animals", from: .main).supportsVisualPrompt)
    }

    @Test("Math and Flags are hidden from a two-year-old")
    func levelThreePacksAreGated() throws {
        for id in ["math", "flags"] {
            let pack = try ContentLoader.load(id, from: .main)
            #expect(!pack.isAvailable(at: .little), "\(id) should not appear at Little")
            #expect(!pack.isAvailable(at: .middle), "\(id) should not appear at Middle")
            #expect(pack.isAvailable(at: .big))
        }
    }
}

@MainActor
struct SettingsStoreTests {

    private func makeStore() -> SettingsStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gin-settings-\(UUID().uuidString).json")
        return SettingsStore(fileURL: url)
    }

    @Test("A new install starts at the youngest level")
    func defaultsToLittle() {
        #expect(makeStore().level == .little)
    }

    @Test("Settings survive a relaunch")
    func settingsPersist() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gin-settings-\(UUID().uuidString).json")

        let first = SettingsStore(fileURL: url)
        first.level = .big
        first.dailyLimitMinutes = 20
        let animals = try ContentLoader.load("animals", from: .main)
        first.setEnabled(false, for: animals)

        let second = SettingsStore(fileURL: url)
        #expect(second.level == .big)
        #expect(second.dailyLimitMinutes == 20)
        #expect(!second.isEnabled(animals))
    }

    @Test("Toggling a pack off and on again is lossless")
    func packTogglingRoundTrips() throws {
        let store = makeStore()
        let animals = try ContentLoader.load("animals", from: .main)

        #expect(store.isEnabled(animals))
        store.setEnabled(false, for: animals)
        #expect(!store.isEnabled(animals))
        store.setEnabled(true, for: animals)
        #expect(store.isEnabled(animals))
    }
}

@MainActor
struct UsageTrackerTests {

    private func makeTracker() -> UsageTracker {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gin-usage-\(UUID().uuidString).json")
        return UsageTracker(fileURL: url)
    }

    @Test("No limit set means the limit is never reached")
    func noLimitNeverTriggers() {
        let tracker = makeTracker()
        #expect(!tracker.hasReachedLimit(nil))
        #expect(tracker.minutesRemaining(nil) == nil)
    }

    @Test("A fresh day starts with the full allowance")
    func freshDayHasFullTime() {
        let tracker = makeTracker()
        #expect(tracker.secondsUsedToday == 0)
        #expect(tracker.minutesRemaining(20) == 20)
        #expect(!tracker.hasReachedLimit(20))
    }

    @Test("Giving more time clears today's usage")
    func resetGivesTimeBack() {
        let tracker = makeTracker()
        tracker.resetToday()
        #expect(tracker.secondsUsedToday == 0)
        #expect(!tracker.hasReachedLimit(10))
    }
}
