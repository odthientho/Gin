import Foundation
import Testing
@testable import Gin

/// Deterministic RNG so a failure is reproducible rather than a once-a-week ghost.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

private func makeItems(_ count: Int) -> [Item] {
    (0 ..< count).map { index in
        Item(
            id: "item\(index)",
            name: "Item \(index)",
            art: Art(kind: .emoji, value: "🐄"),
            voiceClip: "item\(index)"
        )
    }
}

struct RoundBuilderTests {

    @Test("The answer is always among the choices")
    func targetIsAlwaysPresent() {
        let pool = makeItems(8)
        for seed in UInt64(1) ... 50 {
            var generator = SeededGenerator(seed: seed)
            let question = RoundBuilder.findItQuestion(
                from: pool, choiceCount: 3, using: &generator
            )
            let question2 = try? #require(question)
            #expect(question2?.choices.contains(question2!.target) == true)
        }
    }

    @Test("A question offers exactly the level's choice count")
    func choiceCountIsHonored() {
        let pool = makeItems(8)
        for choiceCount in 2 ... 4 {
            var generator = SeededGenerator(seed: 99)
            let question = RoundBuilder.findItQuestion(
                from: pool, choiceCount: choiceCount, using: &generator
            )
            #expect(question?.choices.count == choiceCount)
        }
    }

    @Test("The same item never appears twice in one question")
    func choicesAreUnique() {
        let pool = makeItems(6)
        for seed in UInt64(1) ... 50 {
            var generator = SeededGenerator(seed: seed)
            guard let question = RoundBuilder.findItQuestion(
                from: pool, choiceCount: 4, using: &generator
            ) else { continue }
            #expect(Set(question.choices.map(\.id)).count == question.choices.count)
        }
    }

    @Test("A question does not repeat the previous target")
    func avoidsRepeatingTarget() {
        let pool = makeItems(6)
        for seed in UInt64(1) ... 50 {
            var generator = SeededGenerator(seed: seed)
            let question = RoundBuilder.findItQuestion(
                from: pool, choiceCount: 3, avoiding: "item0", using: &generator
            )
            #expect(question?.target.id != "item0")
        }
    }

    @Test("A two-item pool still produces a question")
    func handlesTinyPool() {
        var generator = SeededGenerator(seed: 7)
        let question = RoundBuilder.findItQuestion(
            from: makeItems(2), choiceCount: 4, using: &generator
        )
        // Can't invent distractors that don't exist — it offers what it has.
        #expect(question?.choices.count == 2)
    }

    @Test("A single-item pool cannot make a question")
    func refusesImpossiblePool() {
        var generator = SeededGenerator(seed: 7)
        #expect(RoundBuilder.findItQuestion(
            from: makeItems(1), choiceCount: 3, using: &generator
        ) == nil)
    }

    @Test("Counting never asks for zero")
    func countingIsNeverZero() {
        let pool = makeItems(5)
        for seed in UInt64(1) ... 100 {
            var generator = SeededGenerator(seed: seed)
            guard let task = RoundBuilder.countingTask(
                from: pool, maxQuantity: 5, using: &generator
            ) else { continue }
            #expect(task.quantity >= 1)
            #expect(task.quantity <= 5)
        }
    }
}

struct GridFitTests {

    @Test("Six tiles lay out three across with no gaps")
    func sixIsBalanced() {
        let columns = GridFit.columnCount(for: 6)
        #expect(columns == 3)
        #expect(GridFit.rows(count: 6, columns: columns) == 2)
        #expect(columns * GridFit.rows(count: 6, columns: columns) - 6 == 0)
    }

    @Test("Layouts never exceed three rows")
    func rowsAreCapped() {
        for count in 2 ... 18 {
            let columns = GridFit.columnCount(for: count)
            #expect(GridFit.rows(count: count, columns: columns) <= 3,
                    "\(count) items produced too many rows")
        }
    }

    @Test("An arrangement that fills exactly is preferred")
    func prefersFullGrids() {
        // 10 fits 5x2 perfectly; 4x3 would leave two holes.
        #expect(GridFit.columnCount(for: 10) == 5)
        // 12 fits both 4x3 and 6x2; the squarer one wins.
        #expect(GridFit.columnCount(for: 12) == 4)
    }

    @Test("Chunking preserves order and never drops an item")
    func chunkingIsLossless() {
        let items = Array(1 ... 11)
        let chunked = GridFit.chunk(items, into: 4)
        #expect(chunked.flatMap { $0 } == items)
        #expect(chunked.count == 3)
    }
}

@MainActor
struct ProgressStoreTests {

    private func makeStore() -> ProgressStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gin-test-\(UUID().uuidString).json")
        return ProgressStore(fileURL: url)
    }

    @Test("Earning the same sticker twice does not duplicate it")
    func awardsAreUnique() {
        let store = makeStore()
        store.award("cow")
        store.award("cow")
        store.award("pig")
        #expect(store.earnedStickerIDs == ["cow", "pig"])
    }

    @Test("An unearned sticker cannot be placed")
    func placementRequiresEarning() {
        let store = makeStore()
        store.place("cow", at: StickerPlacement(x: 0.5, y: 0.5))
        #expect(store.placement(for: "cow") == nil)
    }

    @Test("Placements are clamped into the album")
    func placementsStayOnScreen() {
        let store = makeStore()
        store.award("cow")
        store.place("cow", at: StickerPlacement(x: 1.8, y: -0.4))
        #expect(store.placement(for: "cow") == StickerPlacement(x: 1, y: 0))
    }

    @Test("Progress survives a relaunch")
    func progressPersists() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gin-test-\(UUID().uuidString).json")

        let first = ProgressStore(fileURL: url)
        first.award("cow")
        first.place("cow", at: StickerPlacement(x: 0.25, y: 0.75))

        let second = ProgressStore(fileURL: url)
        #expect(second.earnedStickerIDs == ["cow"])
        #expect(second.placement(for: "cow") == StickerPlacement(x: 0.25, y: 0.75))
    }

    @Test("Unplaced stickers are reported until they are placed")
    func tracksUnplaced() {
        let store = makeStore()
        store.award("cow")
        store.award("pig")
        #expect(store.unplacedStickerIDs.count == 2)

        store.place("cow", at: StickerPlacement(x: 0.1, y: 0.1))
        #expect(store.unplacedStickerIDs == ["pig"])
    }

    @Test("Flashcard positions persist per pack, and old files still decode")
    func flashcardPositionPersists() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gin-test-\(UUID().uuidString).json")

        // A progress file from before flashcards existed — no flashcardIndices
        // key. It must load, not be treated as corrupt and wiped.
        let legacy = #"{"earnedStickerIDs":["cow"],"placements":{},"writingIndex":3}"#
        try legacy.data(using: .utf8)!.write(to: url)

        let store = ProgressStore(fileURL: url)
        #expect(store.earnedStickerIDs == ["cow"], "legacy file was wiped")
        #expect(store.flashcardIndex(for: "flags") == 0)

        store.setFlashcardIndex(23, for: "flags")

        let reloaded = ProgressStore(fileURL: url)
        #expect(reloaded.flashcardIndex(for: "flags") == 23)
        #expect(reloaded.flashcardIndex(for: "animals") == 0)
        #expect(reloaded.earnedStickerIDs == ["cow"])
    }

    @Test("Mastery accumulates, persists, and never doubles")
    func masteryPersists() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gin-test-\(UUID().uuidString).json")

        let store = ProgressStore(fileURL: url)
        #expect(store.mastered(in: "flags").isEmpty)

        store.recordMastered("france", in: "flags")
        store.recordMastered("spain", in: "flags")
        store.recordMastered("france", in: "flags")
        #expect(store.mastered(in: "flags") == ["france", "spain"])
        #expect(store.mastered(in: "animals").isEmpty)

        let reloaded = ProgressStore(fileURL: url)
        #expect(reloaded.mastered(in: "flags") == ["france", "spain"])
    }
}
