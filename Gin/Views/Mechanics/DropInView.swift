import SwiftUI

/// Mechanic 04 — Drop In.
///
/// A silhouette waits at the top; the child drags the matching thing into it.
/// This is the only mechanic that requires a *drag*, which is a genuinely harder
/// motor skill than tapping at two years old — so the snap radius is enormous
/// (the whole upper half counts as "in"), and letting go anywhere near the target
/// succeeds. Precision is never the thing being tested.
struct DropInView: View {
    let pack: Pack
    let params: LevelParams
    let onRoundComplete: (Item) -> Void

    @Environment(AudioService.self) private var audio

    @State private var question: FindItQuestion?
    @State private var dragOffsets: [Item.ID: CGSize] = [:]
    @State private var solvedID: Item.ID?
    @State private var wrongID: Item.ID?
    @State private var shake: CGFloat = 0
    @State private var completed = 0
    @State private var isAdvancing = false
    @State private var targetFrame: CGRect = .zero

    private let boardSpace = "dropin.board"
    private var pool: [Item] { pack.items(for: params) }

    var body: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            promptBar
            silhouette
            tray
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
        .coordinateSpace(name: boardSpace)
        .onAppear {
            Haptics.prepare()
            audio.prewarm(pool.map(\.voiceClip))
            nextTask()
        }
    }

    // MARK: - Pieces

    private var promptBar: some View {
        Button { speakPrompt() } label: {
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

    private var promptText: String {
        guard let question else { return " " }
        return "Put the \(question.target.name.lowercased()) in its place"
    }

    private var silhouette: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 6, dash: solvedID == nil ? [16, 12] : [])
                )
                .foregroundStyle(pack.color.color.opacity(solvedID == nil ? 0.5 : 1))

            if let question {
                if solvedID != nil {
                    ArtView(art: question.target.art, size: 130, tint: .white)
                        .padding(28)
                        .background(pack.color.color, in: Circle())
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // The silhouette: the right shape, no detail, so it reads as a
                    // hole to fill rather than as an answer already given.
                    ArtView(art: question.target.art, size: 130,
                            tint: pack.color.color.opacity(0.30))
                        .opacity(question.target.art.kind == .geometry ? 1 : 0.28)
                        .grayscale(question.target.art.kind == .geometry ? 0 : 1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { targetFrame = geometry.frame(in: .named(boardSpace)) }
                    .onChange(of: geometry.frame(in: .named(boardSpace))) { _, new in
                        targetFrame = new
                    }
            }
        }
        .animation(Motion.pop, value: solvedID)
    }

    private var tray: some View {
        HStack(spacing: Theme.Metrics.minGap) {
            ForEach(question?.choices ?? []) { item in
                draggable(item)
            }
        }
        .frame(height: 190)
    }

    private func draggable(_ item: Item) -> some View {
        let offset = dragOffsets[item.id] ?? .zero
        let isSolved = solvedID == item.id

        return ZStack {
            RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                .fill(pack.color.color)
            ArtView(art: item.art, tint: .white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: Theme.Metrics.minTouchTarget, minHeight: Theme.Metrics.minTouchTarget)
        .shadow(color: Theme.Shadow.color,
                radius: offset == .zero ? Theme.Shadow.radius : Theme.Shadow.radius * 2,
                y: offset == .zero ? Theme.Shadow.y : Theme.Shadow.y * 2)
        .scaleEffect(offset == .zero ? 1 : 1.1)
        .opacity(isSolved ? 0 : 1)
        .offset(offset)
        .modifier(Shake(animatableData: wrongID == item.id ? shake : 0))
        .animation(offset == .zero ? Motion.settle : nil, value: offset)
        .gesture(dragGesture(for: item))
        .accessibilityLabel(item.name)
    }

    private func dragGesture(for item: Item) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(boardSpace))
            .onChanged { value in
                guard !isAdvancing, solvedID == nil else { return }
                dragOffsets[item.id] = value.translation
            }
            .onEnded { value in
                guard !isAdvancing, solvedID == nil, let question else { return }
                defer { dragOffsets[item.id] = nil }

                // Forgiving on purpose: anywhere in the generously-inset target
                // counts, and so does anywhere above the tray.
                let landedInTarget = targetFrame
                    .insetBy(dx: -80, dy: -80)
                    .contains(value.location)

                guard landedInTarget else { return }

                if item.id == question.target.id {
                    accept(item)
                } else {
                    reject(item)
                }
            }
    }

    // MARK: - Flow

    private func nextTask() {
        var generator = SystemRandomNumberGenerator()
        solvedID = nil
        wrongID = nil
        dragOffsets = [:]
        isAdvancing = false

        question = RoundBuilder.findItQuestion(
            from: pool,
            choiceCount: min(params.choiceCount, 3),
            avoiding: question?.target.id,
            using: &generator
        )
        speakPrompt()
    }

    private func speakPrompt() {
        audio.say(promptText)
    }

    private func accept(_ item: Item) {
        isAdvancing = true
        Haptics.snap()
        withAnimation(Motion.pop) { solvedID = item.id }
        audio.speak(item)
        completed += 1

        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            if completed >= RoundBuilder.dropInTasksPerRound {
                completed = 0
                onRoundComplete(item)
            }
            // A sticker never ends play — the next shape is always ready.
            nextTask()
        }
    }

    private func reject(_ item: Item) {
        Haptics.nudge()
        wrongID = item.id
        shake = 0
        withAnimation(.easeInOut(duration: 0.4)) { shake = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(420))
            speakPrompt()
            wrongID = nil
        }
    }
}
