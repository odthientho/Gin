import SwiftUI

/// Mechanics 13 and 14 — reading a clock, in both directions.
///
/// `.readClock` shows one big dial and offers four times in words. `.findClock`
/// says a time and offers four dials. Same generator, same ladder; the reversal
/// is nearly free and the two feel quite different to a child, which is what
/// gives the pack something to rotate between.
///
/// Rungs follow how clocks are actually taught — o'clock, half past, quarters,
/// five minutes, any minute — and unlock after four correct in a row.
struct ClockView: View {
    enum Direction {
        /// See the dial, pick the words.
        case readClock
        /// Hear the words, pick the dial.
        case findClock
    }

    let pack: Pack
    let params: LevelParams
    let direction: Direction
    let onRoundComplete: (Item) -> Void

    @Environment(AudioService.self) private var audio
    @Environment(ProgressStore.self) private var progress

    @State private var puzzle: ClockPuzzle?
    @State private var streak = 0
    @State private var solved = 0
    @State private var chosen: ClockTime?
    @State private var wrong: ClockTime?
    @State private var shake: CGFloat = 0
    @State private var isAdvancing = false

    private var ceiling: ClockTier {
        ClockTier(rawValue: progress.tier(for: pack.id)) ?? .oClock
    }

    var body: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            promptBar
            if let puzzle {
                switch direction {
                case .readClock:
                    dialPrompt(puzzle)
                    wordChoices(puzzle)
                case .findClock:
                    dialChoices(puzzle)
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
                Text(promptText)
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

    private var promptText: String {
        switch direction {
        case .readClock: "What time is it?"
        case .findClock: puzzle.map { "Find \($0.answer.spoken)" } ?? " "
        }
    }

    // MARK: - Read the clock

    private func dialPrompt(_ puzzle: ClockPuzzle) -> some View {
        GeometryReader { geometry in
            ClockFaceView(
                time: puzzle.answer,
                size: min(geometry.size.height, geometry.size.width) * 0.94,
                accent: pack.color.color,
                showsMinuteTicks: puzzle.tier == .anyMinute
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func wordChoices(_ puzzle: ClockPuzzle) -> some View {
        HStack(spacing: Theme.Metrics.minGap) {
            ForEach(puzzle.choices, id: \.self) { time in
                Text(time.spoken)
                    .font(Theme.TypeScale.label)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.Metrics.minTouchTarget)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner,
                                         style: .continuous)
                            .fill(pack.color.color)
                    }
                    .shadow(color: Theme.Shadow.color,
                            radius: Theme.Shadow.radius, y: Theme.Shadow.y)
                    .opacity(chosen == time ? 0.4 : 1)
                    .modifier(Shake(animatableData: wrong == time ? shake : 0))
                    .toddlerTap { choose(time, in: puzzle) }
                    .accessibilityLabel(time.spoken)
            }
        }
        .frame(height: Theme.Metrics.minTouchTarget)
    }

    // MARK: - Find the clock

    private func dialChoices(_ puzzle: ClockPuzzle) -> some View {
        GeometryReader { geometry in
            let spacing = Theme.Metrics.minGap
            let side = min(
                (geometry.size.width - spacing * 3) / 4,
                geometry.size.height
            )
            HStack(spacing: spacing) {
                ForEach(puzzle.choices, id: \.self) { time in
                    ClockFaceView(
                        time: time,
                        size: side,
                        accent: pack.color.color,
                        showsMinuteTicks: puzzle.tier == .anyMinute
                    )
                    .opacity(chosen == time ? 0.4 : 1)
                    .modifier(Shake(animatableData: wrong == time ? shake : 0))
                    .toddlerTap { choose(time, in: puzzle) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Flow

    private func nextPuzzle() {
        var generator = SystemRandomNumberGenerator()
        chosen = nil
        wrong = nil
        isAdvancing = false
        puzzle = ClockPuzzleBuilder.puzzle(upTo: ceiling, using: &generator)
        speakPrompt()
    }

    private func speakPrompt() {
        audio.say(promptText)
    }

    private func choose(_ time: ClockTime, in puzzle: ClockPuzzle) {
        guard !isAdvancing else { return }

        guard time == puzzle.answer else {
            Haptics.nudge()
            wrong = time
            shake = 0
            withAnimation(.easeInOut(duration: 0.4)) { shake = 1 }
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
        withAnimation(Motion.pop) { chosen = time }
        // Always say the answer back, in both directions — hearing "quarter to
        // four" while looking at the dial is most of the teaching.
        audio.say(puzzle.answer.spoken)

        streak += 1
        solved += 1
        unlockNextTierIfEarned()

        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            if solved >= RoundBuilder.roundLength {
                solved = 0
                onRoundComplete(rewardItem(for: puzzle.tier))
            }
            nextPuzzle()
        }
    }

    private func unlockNextTierIfEarned() {
        guard streak >= ClockPuzzleBuilder.answersToUnlockNextTier,
              let next = ClockTier(rawValue: ceiling.rawValue + 1)
        else { return }
        streak = 0
        progress.setTier(next.rawValue, for: pack.id)
    }

    private func rewardItem(for tier: ClockTier) -> Item {
        let index = min(tier.rawValue - 1, pack.items.count - 1)
        return pack.items.indices.contains(index) ? pack.items[index] : pack.items[0]
    }
}
