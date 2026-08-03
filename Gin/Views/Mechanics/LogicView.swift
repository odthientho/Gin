import SwiftUI

/// Mechanic 12 — Logic. Non-verbal reasoning on a ladder.
///
/// Six rungs, from "which duck is not like the others" to a 3×3 matrix with two
/// interacting rules. The same screen serves all of them: a grid of figures and
/// a set of answers, with nothing to read.
///
/// A rung unlocks after four correct in a row and never locks again. Puzzles are
/// then drawn from every rung unlocked, weighted toward the newest — so the top
/// of the ladder is where most of the time goes, but an easy one still turns up,
/// and a child who got lucky on the way up is never stranded above their depth.
///
/// Wrong answers behave like everywhere else in Gin: the figure wobbles, the
/// question is asked again, and nothing is lost. The streak resets, which is the
/// only consequence, and it is invisible.
struct LogicView: View {
    let pack: Pack
    let params: LevelParams
    let onRoundComplete: (Item) -> Void

    @Environment(AudioService.self) private var audio
    @Environment(ProgressStore.self) private var progress

    @State private var puzzle: LogicPuzzle?
    @State private var streak = 0
    @State private var solved = 0
    @State private var chosen: LogicFigure?
    @State private var wrong: LogicFigure?
    @State private var shake: CGFloat = 0
    @State private var isAdvancing = false

    private var ceiling: LogicTier {
        LogicTier(rawValue: progress.logicTier(for: pack.id)) ?? .oddOneOutIdentical
    }

    var body: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            promptBar
            if let puzzle {
                grid(puzzle)
                if !puzzle.isOddOneOut {
                    choiceRow(puzzle)
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
                Text(puzzle?.prompt ?? " ")
                    .font(Theme.TypeScale.prompt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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

    // MARK: - Grid

    private func grid(_ puzzle: LogicPuzzle) -> some View {
        GeometryReader { geometry in
            // Square cells sized to whichever of the two axes runs out first.
            let spacing: CGFloat = 14
            let cell = min(
                (geometry.size.width - spacing * CGFloat(puzzle.columns - 1)) / CGFloat(puzzle.columns),
                (geometry.size.height - spacing * CGFloat(puzzle.rows - 1)) / CGFloat(puzzle.rows)
            )

            VStack(spacing: spacing) {
                ForEach(0 ..< puzzle.rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0 ..< puzzle.columns, id: \.self) { column in
                            cellView(puzzle, index: row * puzzle.columns + column, cell: cell)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func cellView(_ puzzle: LogicPuzzle, index: Int, cell: CGFloat) -> some View {
        let figure = puzzle.cells[index]

        ZStack {
            RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                .fill(Theme.Palette.surface)
                .shadow(color: Theme.Shadow.color, radius: 8, y: 3)

            if let figure {
                FigureView(figure: figure, cell: cell * 0.82)
            } else {
                // The hole. Dashed and empty so it reads as somewhere a thing
                // goes, which is the whole question.
                RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 5, dash: [14, 10]))
                    .foregroundStyle(pack.color.color.opacity(0.55))

                if let chosen {
                    FigureView(figure: chosen, cell: cell * 0.82)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("?")
                        .font(.system(size: cell * 0.34, weight: .heavy, design: .rounded))
                        .foregroundStyle(pack.color.color.opacity(0.5))
                }
            }
        }
        .frame(width: cell, height: cell)
        .modifier(Shake(animatableData: wrong == figure && figure != nil ? shake : 0))
        .overlay(alignment: .topTrailing) {
            if puzzle.isOddOneOut, chosen != nil, figure == puzzle.answer { correctBadge }
        }
        // Only odd-one-out is answered by tapping the grid itself.
        .modifier(
            ConditionalTap(isActive: puzzle.isOddOneOut && figure != nil) {
                if let figure { choose(figure, in: puzzle) }
            }
        )
        .accessibilityLabel(figure?.spokenDescription ?? "Missing")
    }

    // MARK: - Choices

    private func choiceRow(_ puzzle: LogicPuzzle) -> some View {
        HStack(spacing: Theme.Metrics.minGap) {
            ForEach(Array(puzzle.choices.enumerated()), id: \.offset) { _, figure in
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                        .fill(pack.color.color.opacity(0.16))
                    FigureView(figure: figure, cell: Theme.Metrics.minTouchTarget * 0.78)
                }
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Metrics.minTouchTarget)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                        .strokeBorder(pack.color.color.opacity(0.35), lineWidth: 3)
                }
                .opacity(chosen == figure ? 0.35 : 1)
                .modifier(Shake(animatableData: wrong == figure ? shake : 0))
                .toddlerTap { choose(figure, in: puzzle) }
                .accessibilityLabel(figure.spokenDescription)
            }
        }
        .frame(height: Theme.Metrics.minTouchTarget)
    }

    private var correctBadge: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 30, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 60, height: 60)
            .background(Theme.Palette.leaf, in: Circle())
            .offset(x: 14, y: -14)
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Flow

    private func nextPuzzle() {
        var generator = SystemRandomNumberGenerator()
        chosen = nil
        wrong = nil
        isAdvancing = false
        puzzle = LogicPuzzleBuilder.puzzle(upTo: ceiling, using: &generator)
        speakPrompt()
    }

    private func speakPrompt() {
        audio.say(puzzle?.prompt ?? "")
    }

    private func choose(_ figure: LogicFigure, in puzzle: LogicPuzzle) {
        guard !isAdvancing else { return }

        guard figure == puzzle.answer else {
            Haptics.nudge()
            wrong = figure
            shake = 0
            withAnimation(.easeInOut(duration: 0.4)) { shake = 1 }
            // A wrong answer costs the streak and nothing else. The child is not
            // told, and the puzzle stays open.
            streak = 0
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                wrong = nil
                speakPrompt()
            }
            return
        }

        isAdvancing = true
        Haptics.success()
        withAnimation(Motion.pop) { chosen = figure }
        audio.say(figure.spokenDescription)

        streak += 1
        solved += 1
        unlockNextTierIfEarned()

        Task {
            try? await Task.sleep(for: .milliseconds(1300))
            if solved >= RoundBuilder.roundLength {
                solved = 0
                onRoundComplete(rewardItem(for: puzzle.tier))
            }
            nextPuzzle()
        }
    }

    private func unlockNextTierIfEarned() {
        guard streak >= LogicPuzzleBuilder.answersToUnlockNextTier,
              let next = LogicTier(rawValue: ceiling.rawValue + 1)
        else { return }
        streak = 0
        progress.setLogicTier(next.rawValue, for: pack.id)
    }

    /// Stickers are pack items, so each rung has one — reaching a harder rung is
    /// the thing worth collecting here.
    private func rewardItem(for tier: LogicTier) -> Item {
        let items = pack.items
        let index = min(tier.rawValue - 1, items.count - 1)
        return items.indices.contains(index) ? items[index] : items[0]
    }
}

/// Applies `toddlerTap` only when a cell is actually answerable, so matrix cells
/// are inert while odd-one-out cells are not.
private struct ConditionalTap: ViewModifier {
    let isActive: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if isActive {
            content.toddlerTap(perform: action)
        } else {
            content
        }
    }
}
