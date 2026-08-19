import Foundation
import Testing
@testable import Gin

struct ComparisonPuzzleBuilderTests {

    /// The rule the whole pack rests on. If the bigger figure is also the red
    /// one, or the only star, a child can answer every question right without
    /// ever comparing sizes — and nobody would find out.
    @Test("Only size varies within a puzzle")
    func nothingButSizeVaries() {
        for tier in ComparisonTier.allCases {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = ComparisonPuzzleBuilder.puzzle(tier: tier, using: &generator)
                var all = puzzle.figures
                if let reference = puzzle.reference { all.append(reference) }

                #expect(Set(all.map(\.shape)).count == 1,
                        "\(tier) seed \(seed): mixed shapes give the answer away")
                #expect(Set(all.map(\.color)).count == 1,
                        "\(tier) seed \(seed): mixed colours give the answer away")
            }
        }
    }

    /// Two figures four percent apart is not a hard question, it is an unfair
    /// one — the child is right that they look the same.
    @Test("Sizes are always far enough apart to see")
    func gapsArePerceptible() {
        for tier in ComparisonTier.allCases {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = ComparisonPuzzleBuilder.puzzle(tier: tier, using: &generator)
                let sorted = puzzle.figures.map(\.scale).sorted()

                for (smaller, larger) in zip(sorted, sorted.dropFirst()) {
                    #expect(larger / smaller >= tier.minimumRatio - 0.001,
                            "\(tier) seed \(seed): \(smaller) and \(larger) are too close")
                }
            }
        }
    }

    /// The smallest figure still has to be worth looking at.
    @Test("Nothing shrinks to a speck")
    func smallestStaysVisible() {
        for tier in ComparisonTier.allCases {
            var floor = 1.0
            for seed in UInt64(1) ... 300 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = ComparisonPuzzleBuilder.puzzle(tier: tier, using: &generator)
                floor = min(floor, puzzle.figures.map(\.scale).min() ?? 1)
            }
            #expect(floor >= 0.2, "\(tier) can shrink to \(floor) of the cell")
        }
    }

    @Test("Everything fits inside its cell")
    func scalesStayInRange() {
        for tier in ComparisonTier.allCases {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = ComparisonPuzzleBuilder.puzzle(tier: tier, using: &generator)
                for figure in puzzle.figures {
                    #expect(figure.scale > 0 && figure.scale <= 1.0,
                            "\(tier) seed \(seed): scale \(figure.scale)")
                }
            }
        }
    }

    /// The answer has to actually be the biggest, or the "right" answer is a lie.
    @Test("The answer is genuinely the one asked for")
    func answerMatchesTheQuestion() {
        for tier in ComparisonTier.allCases where tier != .putInOrder && tier != .sameSize {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = ComparisonPuzzleBuilder.puzzle(tier: tier, using: &generator)
                let answer = try? #require(puzzle.answer)
                guard let answer else { continue }

                let wantsLargest: Bool
                switch puzzle.question {
                case .comparative(let largest), .superlative(let largest): wantsLargest = largest
                default: continue
                }

                let extreme = wantsLargest
                    ? puzzle.figures.map(\.scale).max()
                    : puzzle.figures.map(\.scale).min()
                #expect(answer.scale == extreme, "\(tier) seed \(seed)")
            }
        }
    }

    /// Comparative for two things, superlative for more. That is how the words
    /// work, and a child hears it long before they could explain it.
    @Test("Two things are compared, three or more are ranked")
    func wordingFollowsTheCount() {
        for tier in ComparisonTier.allCases where tier != .putInOrder && tier != .sameSize {
            for seed in UInt64(1) ... 100 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = ComparisonPuzzleBuilder.puzzle(tier: tier, using: &generator)
                switch puzzle.question {
                case .comparative:
                    #expect(puzzle.figures.count == 2)
                    #expect(puzzle.question.spoken.contains("bigger")
                            || puzzle.question.spoken.contains("smaller"))
                case .superlative:
                    #expect(puzzle.figures.count >= 3)
                    #expect(puzzle.question.spoken.contains("biggest")
                            || puzzle.question.spoken.contains("smallest"))
                default:
                    Issue.record("\(tier) produced \(puzzle.question)")
                }
            }
        }
    }

    @Test("The same-size rung offers exactly one true match")
    func sameSizeHasOneMatch() {
        for seed in UInt64(1) ... 300 {
            var generator = SeededGenerator(seed: seed)
            let puzzle = ComparisonPuzzleBuilder.puzzle(tier: .sameSize, using: &generator)

            let reference = try? #require(puzzle.reference)
            let answer = try? #require(puzzle.answer)
            guard let reference, let answer else { continue }

            #expect(abs(answer.scale - reference.scale) < 1e-9,
                    "seed \(seed): the answer is not the reference's size")

            // Exactly one candidate matches, so there is no second right answer.
            let matches = puzzle.figures.filter { abs($0.scale - reference.scale) < 1e-9 }
            #expect(matches.count == 1, "seed \(seed): \(matches.count) figures match")

            // One larger and one smaller, so "same" cannot be reached by always
            // picking the biggest or always the smallest.
            #expect(puzzle.figures.contains { $0.scale > reference.scale })
            #expect(puzzle.figures.contains { $0.scale < reference.scale })
        }
    }

    @Test("Ordering lists every figure, in the right direction")
    func orderingIsCorrect() {
        for seed in UInt64(1) ... 300 {
            var generator = SeededGenerator(seed: seed)
            let puzzle = ComparisonPuzzleBuilder.puzzle(tier: .putInOrder, using: &generator)

            #expect(puzzle.orderedAnswer.count == puzzle.figures.count)
            #expect(Set(puzzle.orderedAnswer) == Set(puzzle.figures.map(\.id)),
                    "seed \(seed): the order does not cover the figures")

            let byID = Dictionary(uniqueKeysWithValues: puzzle.figures.map { ($0.id, $0.scale) })
            let scalesInOrder = puzzle.orderedAnswer.compactMap { byID[$0] }

            guard case .order(let ascending) = puzzle.question else {
                Issue.record("seed \(seed): wrong question type")
                continue
            }
            let expected = ascending ? scalesInOrder.sorted() : scalesInOrder.sorted(by: >)
            #expect(scalesInOrder == expected, "seed \(seed): \(scalesInOrder)")
        }
    }

    @Test("A single-answer rung has no ordering, and vice versa")
    func answerShapeMatchesTheRung() {
        for tier in ComparisonTier.allCases {
            var generator = SeededGenerator(seed: 42)
            let puzzle = ComparisonPuzzleBuilder.puzzle(tier: tier, using: &generator)
            if tier == .putInOrder {
                #expect(puzzle.answer == nil)
                #expect(!puzzle.orderedAnswer.isEmpty)
                #expect(puzzle.question.isOrdering)
            } else {
                #expect(puzzle.answer != nil)
                #expect(puzzle.orderedAnswer.isEmpty)
                #expect(!puzzle.question.isOrdering)
            }
        }
    }

    // MARK: - The ladder

    @Test("Puzzles never exceed the rung a child has reached")
    func ceilingIsRespected() {
        for ceiling in ComparisonTier.allCases {
            for seed in UInt64(1) ... 200 {
                var generator = SeededGenerator(seed: seed)
                let puzzle = ComparisonPuzzleBuilder.puzzle(upTo: ceiling, using: &generator)
                #expect(puzzle.tier <= ceiling, "got \(puzzle.tier) with ceiling \(ceiling)")
            }
        }
    }

    @Test("Easier rungs stay in circulation once harder ones unlock")
    func easierRungsStillAppear() {
        var seen: Set<ComparisonTier> = []
        for seed in UInt64(1) ... 400 {
            var generator = SeededGenerator(seed: seed)
            seen.insert(ComparisonPuzzleBuilder.puzzle(upTo: .putInOrder, using: &generator).tier)
        }
        #expect(seen.contains(.putInOrder))
        #expect(seen.contains(.bigOrSmall))
        #expect(seen.count >= 3, "only saw \(seen.count) distinct rungs")
    }

    @Test("The ladder runs easy to hard")
    func ladderIsOrdered() {
        #expect(ComparisonTier.allCases.first == .bigOrSmall)
        #expect(ComparisonTier.allCases.last == .putInOrder)
        // Gaps narrow as the rungs climb — that is what makes them harder.
        let ratios = ComparisonTier.allCases.map(\.minimumRatio)
        #expect(ratios.first! > ratios.last!)
    }
}

struct ComparisonPackTests {

    @Test("The Compare pack has a sticker per rung")
    func packMatchesLadder() throws {
        let pack = try ContentLoader.load("comparison", from: .main)
        #expect(pack.mechanics == [.comparison])
        #expect(pack.items.count == ComparisonTier.allCases.count)
        #expect(Set(pack.items.map(\.id)).count == pack.items.count)
    }
}
