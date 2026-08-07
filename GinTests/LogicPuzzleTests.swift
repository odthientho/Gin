import Foundation
import Testing
@testable import Gin

/// Which attributes split the figures three-against-one.
///
/// This is the formal statement of "there is one right answer": exactly one
/// attribute may produce a 3–1 split, and the lone figure on that split must be
/// the intended answer. Two such attributes means two defensible answers, and a
/// child who picks the other one is right and told they are wrong.
private func threeToOneSplits(_ figures: [LogicFigure]) -> [(FigureAttribute, LogicFigure)] {
    var found: [(FigureAttribute, LogicFigure)] = []

    for attribute in FigureAttribute.allCases {
        let keys: [String] = figures.map { figure in
            switch attribute {
            case .shape: figure.shape.rawValue
            case .color: figure.color.rawValue
            case .count: String(figure.count)
            case .size: String(figure.size.rawValue)
            }
        }
        let tally = Dictionary(grouping: keys.indices, by: { keys[$0] })
        guard tally.count == 2,
              let loner = tally.values.first(where: { $0.count == 1 }),
              tally.values.contains(where: { $0.count == 3 })
        else { continue }
        found.append((attribute, figures[loner[0]]))
    }
    return found
}

struct LogicPuzzleBuilderTests {

    // MARK: - Odd one out

    @Test("Odd one out has exactly one defensible answer")
    func oddOneOutIsUnambiguous() {
        for tier in [LogicTier.oddOneOutIdentical, .oddOneOutCategory] {
            for seed in UInt64(1) ... 300 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = LogicPuzzleBuilder.puzzle(tier: tier, using: &generator)
                let figures = puzzle.cells.compactMap { $0 }

                #expect(figures.count == 4)
                #expect(puzzle.cells.allSatisfy { $0 != nil }, "no hole in an odd-one-out")

                let splits = threeToOneSplits(figures)
                #expect(splits.count == 1,
                        "\(tier) seed \(seed): \(splits.count) attributes split 3-1")
                #expect(splits.first?.1 == puzzle.answer,
                        "\(tier) seed \(seed): the lone figure is not the answer")
            }
        }
    }

    @Test("The answer appears exactly once among the figures")
    func answerIsUniqueInTheGrid() {
        for tier in [LogicTier.oddOneOutIdentical, .oddOneOutCategory] {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = LogicPuzzleBuilder.puzzle(tier: tier, using: &generator)
                let matches = puzzle.cells.compactMap { $0 }.filter { $0 == puzzle.answer }
                #expect(matches.count == 1, "\(tier) seed \(seed)")
            }
        }
    }

    @Test("The three that belong really are identical at the easiest rung")
    func easiestRungMatchesOnSight() {
        for seed in UInt64(1) ... 200 {
            var generator = SeededGenerator(seed: seed)
            let puzzle = LogicPuzzleBuilder.puzzle(tier: .oddOneOutIdentical, using: &generator)
            let others = puzzle.cells.compactMap { $0 }.filter { $0 != puzzle.answer }
            #expect(Set(others).count == 1, "seed \(seed): the three should be identical")
        }
    }

    /// The second rung earns its place only if picture-matching stops working.
    @Test("The second rung cannot be solved by matching pictures")
    func secondRungNeedsAProperty() {
        for seed in UInt64(1) ... 200 {
            var generator = SeededGenerator(seed: seed)
            let puzzle = LogicPuzzleBuilder.puzzle(tier: .oddOneOutCategory, using: &generator)
            let others = puzzle.cells.compactMap { $0 }.filter { $0 != puzzle.answer }
            #expect(Set(others).count == 3, "seed \(seed): the three must differ from each other")
        }
    }

    // MARK: - Matrices

    @Test("Every matrix has exactly one hole, in the last cell")
    func matrixHasOneHole() {
        for tier in LogicTier.allCases where !tier.isOddOneOut {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = LogicPuzzleBuilder.puzzle(tier: tier, using: &generator)
                #expect(puzzle.cells.filter { $0 == nil }.count == 1, "\(tier) seed \(seed)")
                #expect(puzzle.cells.last == .some(nil), "the hole should be the last cell")
                #expect(puzzle.cells.count == puzzle.rows * puzzle.columns)
            }
        }
    }

    @Test("The answer is offered, and the choices are distinct")
    func choicesAreUsable() {
        for tier in LogicTier.allCases where !tier.isOddOneOut {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = LogicPuzzleBuilder.puzzle(tier: tier, using: &generator)
                #expect(puzzle.choices.contains(puzzle.answer), "\(tier) seed \(seed)")
                #expect(Set(puzzle.choices).count == puzzle.choices.count)
                #expect(puzzle.choices.count == 4)
            }
        }
    }

    /// What separates a real reasoning puzzle from a spot-the-odd-colour one: a
    /// wrong answer has to be what you get by following all the rules but one.
    @Test("Every distractor differs from the answer in exactly one attribute")
    func distractorsAreNearMisses() {
        for tier in LogicTier.allCases where !tier.isOddOneOut {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = LogicPuzzleBuilder.puzzle(tier: tier, using: &generator)

                for distractor in puzzle.choices where distractor != puzzle.answer {
                    var differences = 0
                    if distractor.shape != puzzle.answer.shape { differences += 1 }
                    if distractor.color != puzzle.answer.color { differences += 1 }
                    if distractor.count != puzzle.answer.count { differences += 1 }
                    if distractor.size != puzzle.answer.size { differences += 1 }
                    #expect(differences == 1,
                            "\(tier) seed \(seed): distractor differs in \(differences) attributes")
                }
            }
        }
    }

    /// The rules have to actually hold, or the "right" answer is arbitrary.
    @Test("A matrix row is internally consistent")
    func matrixRulesHold() {
        for tier in LogicTier.allCases where !tier.isOddOneOut {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = LogicPuzzleBuilder.puzzle(tier: tier, using: &generator)

                // Restore the hole, then check every row varies the same way.
                var cells = puzzle.cells
                cells[cells.count - 1] = puzzle.answer
                let grid = cells.compactMap { $0 }
                #expect(grid.count == puzzle.rows * puzzle.columns)

                // Whatever changes from column 0 to column 1 in the first row
                // must change the same way in every other row.
                func value(_ figure: LogicFigure, _ attribute: FigureAttribute) -> String {
                    switch attribute {
                    case .shape: figure.shape.rawValue
                    case .color: figure.color.rawValue
                    case .count: String(figure.count)
                    case .size: String(figure.size.rawValue)
                    }
                }

                for attribute in FigureAttribute.allCases {
                    let firstRow = (0 ..< puzzle.columns).map { value(grid[$0], attribute) }
                    for row in 1 ..< puzzle.rows {
                        let thisRow = (0 ..< puzzle.columns).map {
                            value(grid[row * puzzle.columns + $0], attribute)
                        }
                        // Either the attribute is constant across a row in every
                        // row, or it varies identically in every row.
                        let firstConstant = Set(firstRow).count == 1
                        let thisConstant = Set(thisRow).count == 1
                        #expect(firstConstant == thisConstant,
                                "\(tier) seed \(seed): \(attribute) varies inconsistently")
                    }
                }
            }
        }
    }

    @Test("The counting rung really does climb across the row")
    func progressionCounts() {
        for seed in UInt64(1) ... 200 {
            var generator = SeededGenerator(seed: seed)
            let puzzle = LogicPuzzleBuilder.puzzle(tier: .matrix3x3Progression, using: &generator)
            var cells = puzzle.cells
            cells[cells.count - 1] = puzzle.answer
            let grid = cells.compactMap { $0 }

            for row in 0 ..< puzzle.rows {
                let counts = (0 ..< puzzle.columns).map { grid[row * puzzle.columns + $0].count }
                #expect(counts == [1, 2, 3], "seed \(seed) row \(row) was \(counts)")
            }
        }
    }

    // MARK: - The ladder

    @Test("Puzzles never exceed the rung a child has reached")
    func ceilingIsRespected() {
        for ceiling in LogicTier.allCases {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = LogicPuzzleBuilder.puzzle(upTo: ceiling, using: &generator)
                #expect(puzzle.tier <= ceiling, "got \(puzzle.tier) with ceiling \(ceiling)")
            }
        }
    }

    /// Sampling below the ceiling is what stops a child being stranded above
    /// their depth after one lucky streak.
    @Test("Easier rungs stay in circulation once harder ones unlock")
    func easierRungsStillAppear() {
        var seen: Set<LogicTier> = []
        for seed in UInt64(1) ... 400 {
            var generator = SeededGenerator(seed: seed)
            seen.insert(LogicPuzzleBuilder.puzzle(upTo: .matrix3x3Progression,
                                                  using: &generator).tier)
        }
        #expect(seen.count >= 4, "only saw \(seen.count) distinct rungs")
        #expect(seen.contains(.matrix3x3Progression), "the newest rung should dominate")
        #expect(seen.contains(.oddOneOutIdentical), "the easiest rung should still turn up")
    }

    @Test("The ladder runs easy to genuinely hard")
    func ladderIsOrdered() {
        #expect(LogicTier.allCases.count == 6)
        #expect(LogicTier.allCases.first == .oddOneOutIdentical)
        #expect(LogicTier.allCases.last == .matrix3x3Progression)
        // The first two are single-row; the rest are grids that grow.
        #expect(LogicTier.oddOneOutIdentical.isOddOneOut)
        #expect(!LogicTier.matrix2x2Single.isOddOneOut)
    }
}

@MainActor
struct LogicProgressTests {

    private func makeStore() -> ProgressStore {
        ProgressStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("gin-test-\(UUID().uuidString).json"))
    }

    @Test("A fresh child starts on the easiest rung")
    func startsAtRungOne() {
        #expect(makeStore().tier(for: "logic") == 1)
    }

    @Test("Rungs never lock again")
    func tiersOnlyRise() {
        let store = makeStore()
        store.setTier(4, for: "logic")
        #expect(store.tier(for: "logic") == 4)

        // A bad run must not demote — that would be the sharpest fail state in
        // an app that deliberately has none.
        store.setTier(2, for: "logic")
        #expect(store.tier(for: "logic") == 4)
    }

    @Test("The rung persists, and older progress files still load")
    func tierPersists() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gin-test-\(UUID().uuidString).json")
        let legacy = #"{"earnedStickerIDs":["cow"],"placements":{},"writingIndex":0}"#
        try legacy.data(using: .utf8)!.write(to: url)

        let store = ProgressStore(fileURL: url)
        #expect(store.earnedStickerIDs == ["cow"], "a pre-Logic file was wiped")
        #expect(store.tier(for: "logic") == 1)

        store.setTier(5, for: "logic")
        #expect(ProgressStore(fileURL: url).tier(for: "logic") == 5)
    }
}

struct LogicPackTests {

    @Test("The Logic pack has a sticker for every rung")
    func packMatchesLadder() throws {
        let pack = try ContentLoader.load("logic", from: .main)
        #expect(pack.mechanics == [.logic])
        #expect(pack.items.count == LogicTier.allCases.count)
        #expect(Set(pack.items.map(\.id)).count == pack.items.count)
    }
}
