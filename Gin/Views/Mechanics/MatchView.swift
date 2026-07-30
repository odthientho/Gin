import SwiftUI

/// Mechanic 03 — Match.
///
/// At the youngest level every card stays face-up, which makes this a *matching*
/// game rather than a memory game. Recall is a separate, later skill; requiring
/// it at two turns the mechanic from "find the two that are the same" into an
/// impossible task, and the child simply taps at random until something happens.
///
/// From the middle level the cards flip face-down after a short preview, and it
/// becomes the memory game an older child wants.
struct MatchView: View {
    let pack: Pack
    let params: LevelParams
    let onRoundComplete: (Item) -> Void

    @Environment(AudioService.self) private var audio

    private struct Card: Identifiable, Equatable {
        let id = UUID()
        let item: Item
        /// Both halves of a pair share this.
        let pairID: String
    }

    @State private var cards: [Card] = []
    @State private var selected: [Card.ID] = []
    @State private var matched: Set<String> = []
    @State private var wrongIDs: Set<Card.ID> = []
    @State private var shake: CGFloat = 0
    @State private var isPreviewing = true
    @State private var isResolving = false

    private var pool: [Item] { pack.items(for: params) }

    var body: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            promptBar
            grid
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
        .onAppear {
            Haptics.prepare()
            audio.prewarm(pool.map(\.voiceClip))
            deal()
        }
    }

    // MARK: - Pieces

    private var promptBar: some View {
        Button {
            audio.say("Find the two that are the same")
        } label: {
            HStack(spacing: 20) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 36, weight: .semibold))
                Text("Find two that are the same")
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

    private var grid: some View {
        let columns = GridFit.columnCount(for: cards.count, maxRows: 2)

        return VStack(spacing: Theme.Metrics.minGap) {
            ForEach(Array(GridFit.chunk(cards, into: columns).enumerated()), id: \.offset) { _, row in
                HStack(spacing: Theme.Metrics.minGap) {
                    ForEach(row) { card in
                        cardView(card)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func cardView(_ card: Card) -> some View {
        let isMatched = matched.contains(card.pairID)
        let isSelected = selected.contains(card.id)
        let isFaceUp = !params.matchHidesCards || isPreviewing || isSelected || isMatched

        return ZStack {
            RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                .fill(isFaceUp ? pack.color.color : Theme.Palette.inkSoft.opacity(0.55))

            if isFaceUp {
                ItemArtView(item: card.item, tint: .white)
            } else {
                Text("?")
                    .font(.system(size: 76, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: Theme.Metrics.minTouchTarget, minHeight: Theme.Metrics.minTouchTarget)
        .opacity(isMatched ? 0.45 : 1)
        .overlay(alignment: .topTrailing) {
            if isMatched {
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Theme.Palette.leaf, in: Circle())
                    .offset(x: 14, y: -14)
            }
        }
        .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, y: Theme.Shadow.y)
        .modifier(Shake(animatableData: wrongIDs.contains(card.id) ? shake : 0))
        .animation(Motion.pop, value: isFaceUp)
        .animation(Motion.settle, value: isMatched)
        .toddlerTap { select(card) }
        .accessibilityLabel(isFaceUp ? card.item.name : "Hidden card")
    }

    // MARK: - Flow

    private func deal() {
        let chosen = pool.shuffled().prefix(min(params.matchPairs, pool.count))
        cards = chosen.flatMap { item in
            [Card(item: item, pairID: item.id), Card(item: item, pairID: item.id)]
        }.shuffled()

        selected = []
        matched = []
        isResolving = false
        isPreviewing = true

        guard params.matchHidesCards else {
            isPreviewing = false
            return
        }
        // A preview before hiding, so the child knows what is in play. Without it
        // the first few taps are pure guessing, which is not a game.
        Task {
            try? await Task.sleep(for: .milliseconds(2600))
            withAnimation(Motion.settle) { isPreviewing = false }
        }
    }

    private func select(_ card: Card) {
        guard !isResolving,
              !isPreviewing || !params.matchHidesCards,
              !matched.contains(card.pairID),
              !selected.contains(card.id)
        else { return }

        Haptics.tap()
        audio.speak(card.item)
        selected.append(card.id)

        guard selected.count == 2 else { return }
        resolvePair()
    }

    private func resolvePair() {
        let picked = selected.compactMap { id in cards.first { $0.id == id } }
        guard picked.count == 2 else { selected = []; return }

        isResolving = true

        if picked[0].pairID == picked[1].pairID {
            Haptics.success()
            withAnimation(Motion.pop) { matched.insert(picked[0].pairID) }
            selected = []
            isResolving = false

            guard matched.count == Set(cards.map(\.pairID)).count else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                onRoundComplete(picked[0].item)
            }
        } else {
            Haptics.nudge()
            wrongIDs = Set(picked.map(\.id))
            shake = 0
            withAnimation(.easeInOut(duration: 0.4)) { shake = 1 }

            Task {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(Motion.settle) {
                    selected = []
                    wrongIDs = []
                }
                isResolving = false
            }
        }
    }
}
