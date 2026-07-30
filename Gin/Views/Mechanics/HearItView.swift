import SwiftUI

/// Mechanic 06 — Hear It.
///
/// A sound plays and the child picks what made it. Pure auditory discrimination,
/// with no text and no spoken word to lean on — which makes it the one mechanic
/// that works identically for a child who speaks no English at all.
///
/// It is also the one mechanic that genuinely cannot ship without real recordings:
/// a synthesized voice saying "cow" instead of a moo turns it back into Find It.
/// ``PackView`` hides it until the effect clips exist.
struct HearItView: View {
    let pack: Pack
    let params: LevelParams
    let onRoundComplete: (Item) -> Void

    @Environment(AudioService.self) private var audio

    @State private var question: FindItQuestion?
    @State private var answered = 0
    @State private var correctID: Item.ID?
    @State private var wrongID: Item.ID?
    @State private var shake: CGFloat = 0
    @State private var isAdvancing = false

    /// Only items that actually have a sound can be asked about.
    private var pool: [Item] {
        pack.items(for: params).filter { audio.hasClip($0.effectClip) }
    }

    var body: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            listenButton

            if let question {
                HStack(spacing: Theme.Metrics.minGap) {
                    ForEach(question.choices) { item in
                        ItemTile(
                            item: item,
                            color: pack.color.color,
                            isActive: correctID == item.id
                        ) {
                            choose(item, in: question)
                        }
                        .modifier(Shake(animatableData: wrongID == item.id ? shake : 0))
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
        .onAppear {
            Haptics.prepare()
            audio.prewarm(pool.compactMap(\.effectClip))
            nextQuestion()
        }
    }

    // MARK: - Pieces

    /// Deliberately huge. Replaying the sound is the core verb of this mechanic,
    /// not an accessibility afterthought, so it gets the biggest target on screen.
    private var listenButton: some View {
        Button { replay() } label: {
            HStack(spacing: 24) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 54, weight: .bold))
                Text("What made this sound?")
                    .font(Theme.TypeScale.prompt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 52)
            .padding(.vertical, 30)
            .background(pack.color.color, in: Capsule())
            .shadow(color: Theme.Shadow.color, radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play the sound again")
    }

    // MARK: - Flow

    private func nextQuestion() {
        var generator = SystemRandomNumberGenerator()
        correctID = nil
        wrongID = nil
        isAdvancing = false

        question = RoundBuilder.findItQuestion(
            from: pool,
            choiceCount: params.choiceCount,
            avoiding: question?.target.id,
            using: &generator
        )
        replay()
    }

    private func replay() {
        guard let question else { return }
        audio.playEffect(question.target.effectClip)
    }

    private func choose(_ item: Item, in question: FindItQuestion) {
        guard !isAdvancing else { return }

        if item.id == question.target.id {
            isAdvancing = true
            Haptics.success()
            withAnimation(Motion.pop) { correctID = item.id }
            audio.speak(item)
            answered += 1

            Task {
                try? await Task.sleep(for: .milliseconds(1200))
                if answered >= RoundBuilder.questionsPerRound {
                    answered = 0
                    onRoundComplete(question.target)
                }
                // A sticker never ends play — the next question is always ready.
                nextQuestion()
            }
        } else {
            Haptics.nudge()
            wrongID = item.id
            shake = 0
            withAnimation(.easeInOut(duration: 0.4)) { shake = 1 }
            Task {
                try? await Task.sleep(for: .milliseconds(420))
                replay()
            }
        }
    }
}
