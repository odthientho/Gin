import SwiftUI

/// Mechanic 02 — "Where is the cow?", and its mirror image.
///
/// One question, three or four choices, nothing else on screen. The prompt is
/// spoken; the written text exists only so an adult can follow along.
///
/// **A wrong tap is not a failure.** The card shakes, the question repeats, and
/// that is the entire consequence — the choice is never removed, never marked
/// red, and the round never ends early. This is the mechanic where it would be
/// easiest to accidentally build a test, so the absence of scoring here is
/// deliberate and load-bearing.
///
/// ## Both directions
///
/// For a pack that supports it (Flags & Countries), each question flips a coin on
/// direction, which is how "show a flag, pick the country" and "say a country,
/// pick the flag" are the same code with one parameter:
///
/// - ``PromptType/audio`` — the name is spoken, the choices are pictures.
/// - ``PromptType/visual`` — the picture is shown, the choices are names.
///
/// In the visual direction every choice is **read aloud before the child picks**.
/// A four-year-old cannot read "Switzerland", so a silent list of words would make
/// the whole thing a guess.
struct FindItView: View {
    let pack: Pack
    let params: LevelParams
    let onRoundComplete: (Item) -> Void

    @Environment(AudioService.self) private var audio

    @State private var question: FindItQuestion?
    @State private var direction: PromptType = .audio
    @State private var answeredCount = 0
    @State private var correctItemID: Item.ID?
    @State private var wrongItemID: Item.ID?
    @State private var shake: CGFloat = 0
    @State private var isAdvancing = false

    private var pool: [Item] { pack.items(for: params) }

    var body: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            if let question {
                if direction == .visual {
                    visualPrompt(question)
                    nameChoices(question)
                } else {
                    promptBar
                    pictureChoices(question)
                }
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
        .onAppear {
            Haptics.prepare()
            audio.prewarm(pool.map(\.voiceClip))
            nextQuestion()
        }
    }

    // MARK: - Audio direction

    private var promptBar: some View {
        Button { askAgain() } label: {
            HStack(spacing: 20) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 36, weight: .semibold))
                Text(promptText)
                    .font(Theme.TypeScale.prompt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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

    private func pictureChoices(_ question: FindItQuestion) -> some View {
        HStack(spacing: Theme.Metrics.minGap) {
            ForEach(question.choices) { item in
                ItemTile(
                    item: item,
                    color: pack.color.color,
                    isActive: correctItemID == item.id
                ) {
                    choose(item, in: question)
                }
                .modifier(Shake(animatableData: wrongItemID == item.id ? shake : 0))
                .overlay(alignment: .topTrailing) {
                    if correctItemID == item.id { correctBadge }
                }
            }
        }
    }

    // MARK: - Visual direction

    private func visualPrompt(_ question: FindItQuestion) -> some View {
        Button { askAgain() } label: {
            VStack(spacing: 16) {
                ItemArtView(item: question.target, size: 150)
                HStack(spacing: 14) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 30, weight: .semibold))
                    Text("Which one is this?")
                        .font(Theme.TypeScale.label)
                }
                .foregroundStyle(Theme.Palette.inkSoft)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(28)
            .background(Theme.Palette.surface,
                        in: RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner,
                                             style: .continuous))
            .shadow(color: Theme.Shadow.color, radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hear the choices again")
    }

    private func nameChoices(_ question: FindItQuestion) -> some View {
        HStack(spacing: Theme.Metrics.minGap) {
            ForEach(question.choices) { item in
                Text(item.name)
                    .font(Theme.TypeScale.label)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.Metrics.minTouchTarget)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner,
                                         style: .continuous)
                            .fill(pack.color.color)
                    }
                    .overlay(alignment: .topTrailing) {
                        if correctItemID == item.id { correctBadge }
                    }
                    .shadow(color: Theme.Shadow.color,
                            radius: Theme.Shadow.radius, y: Theme.Shadow.y)
                    .scaleEffect(correctItemID == item.id ? 1.06 : 1)
                    .animation(Motion.pop, value: correctItemID)
                    .modifier(Shake(animatableData: wrongItemID == item.id ? shake : 0))
                    .toddlerTap { choose(item, in: question) }
                    .accessibilityLabel(item.name)
            }
        }
        .frame(height: Theme.Metrics.minTouchTarget)
    }

    // MARK: - Shared

    private var correctBadge: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 34, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 68, height: 68)
            .background(Theme.Palette.leaf, in: Circle())
            .shadow(color: Theme.Shadow.color, radius: 8, y: 3)
            .offset(x: 16, y: -16)
            .transition(.scale.combined(with: .opacity))
    }

    private var promptText: String {
        guard let question else { return " " }
        return "Where is the \(question.target.name.lowercased())?"
    }

    // MARK: - Flow

    private func nextQuestion() {
        var generator = SystemRandomNumberGenerator()
        correctItemID = nil
        wrongItemID = nil
        isAdvancing = false

        question = RoundBuilder.findItQuestion(
            from: pool,
            choiceCount: params.choiceCount,
            avoiding: question?.target.id,
            using: &generator
        )

        // Alternate directions only where the content supports it.
        direction = pack.supportsVisualPrompt && Bool.random() ? .visual : .audio
        askAgain()
    }

    private func askAgain() {
        guard let question else { return }

        switch direction {
        case .audio:
            audio.say(promptText)
        case .visual:
            // Read the options out. Without this, a pre-reader is guessing.
            let names = question.choices.map(\.name)
            audio.say("Is it \(names.joined(separator: ", "))?")
        }
    }

    private func choose(_ item: Item, in question: FindItQuestion) {
        // Ignore taps during the celebrate-and-advance beat, so a fast child
        // can't skip two questions with one flurry of taps.
        guard !isAdvancing else { return }

        if item.id == question.target.id {
            isAdvancing = true
            Haptics.success()
            withAnimation(Motion.pop) { correctItemID = item.id }
            audio.speak(item)

            answeredCount += 1
            Task {
                try? await Task.sleep(for: .milliseconds(1200))
                if answeredCount >= RoundBuilder.questionsPerRound {
                    answeredCount = 0
                    onRoundComplete(question.target)
                } else {
                    nextQuestion()
                }
            }
        } else {
            Haptics.nudge()
            wrongItemID = item.id
            shake = 0
            withAnimation(.easeInOut(duration: 0.4)) { shake = 1 }
            // Re-ask rather than say anything discouraging.
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                askAgain()
                wrongItemID = nil
            }
        }
    }
}
