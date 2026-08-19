import SwiftUI

/// Mechanic 15 — Comparison. Bigger, smaller, the same, and putting things in order.
///
/// Five rungs, from two figures that are obviously different to four that have to
/// be sorted. Every figure in a puzzle is the same shape and colour, so the only
/// thing that can be compared is size.
///
/// The last rung is the interesting one. Ordering four things is not four more
/// comparisons — it is every pair holding at once, which is a genuinely later
/// skill than picking the biggest. It is answered by tapping in sequence rather
/// than dragging: a drag is a fine motor problem on top of a thinking problem,
/// and only one of those is the point.
struct ComparisonView: View {
    let pack: Pack
    let params: LevelParams
    let onRoundComplete: (Item) -> Void

    @Environment(AudioService.self) private var audio
    @Environment(ProgressStore.self) private var progress

    @State private var puzzle: ComparisonPuzzle?
    @State private var streak = 0
    @State private var solved = 0
    @State private var chosen: ComparisonFigure.ID?
    @State private var wrong: ComparisonFigure.ID?
    @State private var shake: CGFloat = 0
    @State private var isAdvancing = false
    /// Ids tapped so far, for the ordering rung.
    @State private var placed: [ComparisonFigure.ID] = []

    private var ceiling: ComparisonTier {
        ComparisonTier(rawValue: progress.tier(for: pack.id)) ?? .bigOrSmall
    }

    var body: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            promptBar
            if let puzzle {
                GeometryReader { geometry in
                    // One cell size for every figure on screen, the reference
                    // included. Sizing the two rows separately is exactly how
                    // "which is the same size?" became unanswerable: two figures
                    // with an identical scale drew at different sizes because
                    // their cells differed, so nothing on screen matched.
                    let cell = figureCell(for: puzzle, in: geometry.size)

                    VStack(spacing: Theme.Metrics.minGap) {
                        if let reference = puzzle.reference {
                            referenceTile(reference, cell: cell)
                        }
                        figureRow(puzzle, cell: cell)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
        .onAppear {
            Haptics.prepare()
            nextPuzzle()
        }
    }

    // MARK: - Prompt

    private var promptBar: some View {
        Button { speakPrompt() } label: {
            HStack(spacing: 20) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 34, weight: .semibold))
                Text(puzzle?.question.spoken ?? " ")
                    .font(Theme.TypeScale.prompt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .foregroundStyle(Theme.Palette.ink)
            .padding(.horizontal, 40)
            .padding(.vertical, 18)
            .background(Theme.Palette.surface, in: Capsule())
            .shadow(color: Theme.Shadow.color, radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hear the question again")
    }

    /// The largest square that fits every figure, reference row included.
    private func figureCell(for puzzle: ComparisonPuzzle, in size: CGSize) -> CGFloat {
        let spacing = Theme.Metrics.minGap
        let columns = CGFloat(max(1, puzzle.figures.count))
        let rows: CGFloat = puzzle.reference == nil ? 1 : 2
        return max(0, min(
            (size.width - spacing * (columns - 1)) / columns,
            (size.height - spacing * (rows - 1)) / rows
        ))
    }

    /// The figure to match against.
    ///
    /// Marked out by its dashed border and its own row, never by being drawn at
    /// a different size — size is the answer here, so the reference has to be
    /// measured against the candidates on exactly the same scale.
    private func referenceTile(_ figure: ComparisonFigure, cell: CGFloat) -> some View {
        ComparisonFigureView(figure: figure, cell: cell * 0.84)
            .frame(width: cell, height: cell)
            .background {
                RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                    .fill(pack.color.color.opacity(0.12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                    .strokeBorder(
                        pack.color.color.opacity(0.7),
                        style: StrokeStyle(lineWidth: 5, dash: [14, 10])
                    )
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Match this one")
    }

    // MARK: - Figures

    private func figureRow(_ puzzle: ComparisonPuzzle, cell: CGFloat) -> some View {
        HStack(spacing: Theme.Metrics.minGap) {
            ForEach(puzzle.figures) { figure in
                tile(figure, in: puzzle, cell: cell)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tile(
        _ figure: ComparisonFigure,
        in puzzle: ComparisonPuzzle,
        cell: CGFloat
    ) -> some View {
        let order = placed.firstIndex(of: figure.id)
        let isSettled = order != nil || chosen == figure.id

        return ZStack {
            RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                .fill(Theme.Palette.surface)
                .shadow(color: Theme.Shadow.color, radius: 8, y: 3)

            // Every tile is the same size; only the figure inside it differs.
            // Sizing the tiles would give the answer away without the child ever
            // looking at the shapes.
            ComparisonFigureView(figure: figure, cell: cell * 0.84)

            if let order {
                Text("\(order + 1)")
                    .font(.system(size: cell * 0.2, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: cell * 0.3, height: cell * 0.3)
                    .background(Theme.Palette.leaf, in: Circle())
                    .position(x: cell * 0.82, y: cell * 0.18)
            }
        }
        .frame(width: cell, height: cell)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                .strokeBorder(
                    isSettled ? Theme.Palette.leaf : pack.color.color.opacity(0.3),
                    lineWidth: isSettled ? 6 : 3
                )
        }
        .opacity(chosen == figure.id ? 0.55 : 1)
        .modifier(Shake(animatableData: wrong == figure.id ? shake : 0))
        .animation(Motion.pop, value: isSettled)
        .toddlerTap { choose(figure, in: puzzle) }
        .accessibilityLabel(Text(figure.shape.rawValue))
    }

    // MARK: - Flow

    private func nextPuzzle() {
        var generator = SystemRandomNumberGenerator()
        chosen = nil
        wrong = nil
        placed = []
        isAdvancing = false
        puzzle = ComparisonPuzzleBuilder.puzzle(upTo: ceiling, using: &generator)
        speakPrompt()
    }

    private func speakPrompt() {
        audio.say(puzzle?.question.spoken ?? "")
    }

    private func choose(_ figure: ComparisonFigure, in puzzle: ComparisonPuzzle) {
        guard !isAdvancing else { return }

        if puzzle.question.isOrdering {
            chooseInOrder(figure, in: puzzle)
        } else {
            chooseSingle(figure, in: puzzle)
        }
    }

    private func chooseSingle(_ figure: ComparisonFigure, in puzzle: ComparisonPuzzle) {
        guard figure.id == puzzle.answer?.id else {
            reject(figure)
            return
        }
        isAdvancing = true
        Haptics.success()
        withAnimation(Motion.pop) { chosen = figure.id }
        audio.say(successWord(for: puzzle.question))
        advance(tier: puzzle.tier)
    }

    private func chooseInOrder(_ figure: ComparisonFigure, in puzzle: ComparisonPuzzle) {
        // Already placed: a repeat tap is a no-op, not a mistake.
        guard !placed.contains(figure.id) else { return }

        guard puzzle.orderedAnswer[placed.count] == figure.id else {
            reject(figure)
            return
        }

        Haptics.success()
        withAnimation(Motion.pop) { placed.append(figure.id) }
        audio.say(ClockTime.word(placed.count))

        guard placed.count == puzzle.orderedAnswer.count else { return }
        isAdvancing = true
        audio.say("In order!")
        advance(tier: puzzle.tier)
    }

    private func reject(_ figure: ComparisonFigure) {
        Haptics.nudge()
        wrong = figure.id
        shake = 0
        withAnimation(.easeInOut(duration: 0.4)) { shake = 1 }
        streak = 0
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            wrong = nil
            speakPrompt()
        }
    }

    private func successWord(for question: ComparisonQuestion) -> String {
        switch question {
        case .comparative(let wantsLargest): wantsLargest ? "Bigger!" : "Smaller!"
        case .superlative(let wantsLargest): wantsLargest ? "The biggest!" : "The smallest!"
        case .sameSize: "The same!"
        case .order: "In order!"
        }
    }

    private func advance(tier: ComparisonTier) {
        streak += 1
        solved += 1
        unlockNextTierIfEarned()

        Task {
            try? await Task.sleep(for: .milliseconds(1300))
            if solved >= RoundBuilder.roundLength {
                solved = 0
                onRoundComplete(rewardItem(for: tier))
            }
            nextPuzzle()
        }
    }

    private func unlockNextTierIfEarned() {
        guard streak >= ComparisonPuzzleBuilder.answersToUnlockNextTier,
              let next = ComparisonTier(rawValue: ceiling.rawValue + 1)
        else { return }
        streak = 0
        progress.setTier(next.rawValue, for: pack.id)
    }

    private func rewardItem(for tier: ComparisonTier) -> Item {
        let index = min(tier.rawValue - 1, pack.items.count - 1)
        return pack.items.indices.contains(index) ? pack.items[index] : pack.items[0]
    }
}

/// One figure at an arbitrary size, filling `scale` of the cell it is given.
struct ComparisonFigureView: View {
    let figure: ComparisonFigure
    let cell: CGFloat

    var body: some View {
        FigureView.shape(figure.shape)
            .fill(figure.color.color)
            .frame(width: cell * figure.scale, height: cell * figure.scale)
            .frame(width: cell, height: cell)
    }
}
