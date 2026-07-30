import SwiftUI

/// Mechanic 09 — Patterns.
///
/// A repeating run with the next element withheld. This is the mechanic that
/// actually earns its place on developmental grounds: recognising that *red, blue,
/// red, blue* implies *red* is the same cognitive move as recognising that numbers
/// continue, and it arrives well before arithmetic does. The plan calls it the real
/// precursor to mathematics, and it is.
///
/// The visible run always contains the motif twice. One repetition is a row of
/// things, not a pattern — there is nothing to infer from a single instance.
struct PatternsView: View {
    let pack: Pack
    let params: LevelParams
    let onRoundComplete: (Item) -> Void

    @Environment(AudioService.self) private var audio

    @State private var task: PatternTask?
    @State private var chosenID: Item.ID?
    @State private var wrongID: Item.ID?
    @State private var shake: CGFloat = 0
    @State private var solved = 0
    @State private var isAdvancing = false

    private var pool: [Item] { pack.items(for: params) }

    var body: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            promptBar

            if let task {
                sequenceRow(task)
                choiceRow(task)
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
        .onAppear {
            Haptics.prepare()
            nextTask()
        }
    }

    // MARK: - Pieces

    private var promptBar: some View {
        Button { speakPrompt() } label: {
            HStack(spacing: 20) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 36, weight: .semibold))
                Text("What comes next?")
                    .font(Theme.TypeScale.prompt)
            }
            .foregroundStyle(Theme.Palette.ink)
            .padding(.horizontal, 44)
            .padding(.vertical, 22)
            .background(Theme.Palette.surface, in: Capsule())
            .shadow(color: Theme.Shadow.color, radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Repeat the question")
    }

    private func sequenceRow(_ task: PatternTask) -> some View {
        HStack(spacing: 16) {
            ForEach(Array(task.sequence.enumerated()), id: \.offset) { _, item in
                ItemArtView(item: item, size: 74)
                    .frame(width: 116, height: 116)
                    .background(Theme.Palette.surface, in: Circle())
                    .shadow(color: Theme.Shadow.color, radius: 6, y: 3)
            }

            Image(systemName: "arrow.right")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.Palette.inkSoft)

            // The gap. Dashed and empty so it reads as somewhere a thing goes,
            // rather than as a thing that is already there.
            ZStack {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 5, dash: [12, 9]))
                    .foregroundStyle(pack.color.color.opacity(0.6))

                if let chosenID, let chosen = task.choices.first(where: { $0.id == chosenID }) {
                    ItemArtView(item: chosen, size: 74)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("?")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(pack.color.color.opacity(0.55))
                }
            }
            .frame(width: 132, height: 132)
            .animation(Motion.pop, value: chosenID)
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Pattern: " + task.sequence.map(\.name).joined(separator: ", ") + ", then?"
        )
    }

    private func choiceRow(_ task: PatternTask) -> some View {
        HStack(spacing: Theme.Metrics.minGap) {
            ForEach(task.choices) { item in
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                        .fill(pack.color.color)
                    ItemArtView(item: item, size: 84)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 168)
                .frame(minWidth: Theme.Metrics.minTouchTarget)
                .shadow(color: Theme.Shadow.color,
                        radius: Theme.Shadow.radius, y: Theme.Shadow.y)
                .opacity(chosenID == item.id ? 0.4 : 1)
                .modifier(Shake(animatableData: wrongID == item.id ? shake : 0))
                .toddlerTap { choose(item, in: task) }
                .accessibilityLabel(item.name)
            }
        }
    }

    // MARK: - Flow

    private func nextTask() {
        var generator = SystemRandomNumberGenerator()
        chosenID = nil
        wrongID = nil
        isAdvancing = false
        task = RoundBuilder.patternTask(from: pool, using: &generator)
        speakPrompt()
    }

    private func speakPrompt() {
        audio.say("What comes next?")
    }

    private func choose(_ item: Item, in task: PatternTask) {
        guard !isAdvancing else { return }

        if item.id == task.answer.id {
            isAdvancing = true
            Haptics.success()
            withAnimation(Motion.pop) { chosenID = item.id }
            audio.speak(item)
            solved += 1

            Task {
                try? await Task.sleep(for: .milliseconds(1300))
                if solved >= RoundBuilder.patternsPerRound {
                    solved = 0
                    onRoundComplete(task.answer)
                } else {
                    nextTask()
                }
            }
        } else {
            Haptics.nudge()
            wrongID = item.id
            shake = 0
            withAnimation(.easeInOut(duration: 0.4)) { shake = 1 }
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                speakPrompt()
                wrongID = nil
            }
        }
    }
}
