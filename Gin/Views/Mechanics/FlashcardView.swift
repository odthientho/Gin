import SwiftUI

/// Mechanic 11 — Flashcards. Learning before testing.
///
/// One big card. The front is the picture alone — for Flags, a flag nearly the
/// width of the screen and nothing else. Tap it and it turns over, says the
/// name, shows the word, and after a beat turns back and brings the next card.
/// That is the entire interaction: look, tap, hear, next.
///
/// This is what a pack with too many items for a Discover grid opens into.
/// Discover's job — free exploration with no questions asked — is done here one
/// item at a time instead of eighteen tiles at once, which is also the only
/// honest way to show 195 flags on a screen that never scrolls.
///
/// The deck runs in pack order, which for Flags is a familiarity ranking:
/// France before Fiji, Japan before Djibouti. The position persists, so a child
/// who got to Croatia yesterday starts at Croatia today, and the deck wraps
/// back to the start when it runs out.
struct FlashcardView: View {
    let pack: Pack
    let params: LevelParams

    @Environment(AudioService.self) private var audio
    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isFlipped = false
    /// Increments on every advance so a stale auto-advance task can tell it has
    /// been superseded by an impatient tap.
    @State private var generation = 0

    private var items: [Item] { pack.items(for: params) }

    private var index: Int {
        let stored = progress.flashcardIndex(for: pack.id)
        return items.indices.contains(stored) ? stored : 0
    }

    private var item: Item? { items.indices.contains(index) ? items[index] : nil }

    var body: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            if let item {
                card(item)
            }
            controls
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
        .onAppear { Haptics.prepare() }
    }

    // MARK: - Card

    private func card(_ item: Item) -> some View {
        ZStack {
            front(item)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped && !reduceMotion ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )

            back(item)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped || reduceMotion ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : Motion.settle, value: isFlipped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toddlerTap { flip(item) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFlipped ? item.name : "Card. Tap to turn it over")
        .accessibilityAddTraits(.isButton)
    }

    private func front(_ item: Item) -> some View {
        cardSurface(fill: Theme.Palette.surface) {
            // The point of the exercise: the picture as big as the card allows.
            ItemArtView(item: item, size: 450)
        }
    }

    private func back(_ item: Item) -> some View {
        cardSurface(fill: pack.color.color) {
            VStack(spacing: 24) {
                ItemArtView(item: item, size: 180)
                Text(item.name)
                    .font(Theme.TypeScale.display)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
            }
            .padding(40)
        }
    }

    private func cardSurface(fill: Color, @ViewBuilder content: () -> some View) -> some View {
        RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner, style: .continuous)
            .fill(fill)
            .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, y: Theme.Shadow.y)
            .overlay(content())
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner, style: .continuous))
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: Theme.Metrics.minGap) {
            chevron("chevron.left", label: "Previous card", isEnabled: index > 0) {
                show(index - 1)
            }
            chevron("chevron.right", label: "Next card",
                    isEnabled: true, tint: pack.color.color) {
                show((index + 1) % items.count)
            }
        }
        .frame(height: 96)
    }

    private func chevron(
        _ systemName: String,
        label: String,
        isEnabled: Bool,
        tint: Color = Theme.Palette.ink,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(isEnabled ? tint : Theme.Palette.inkSoft.opacity(0.35))
                .frame(width: 96, height: 96)
                .background(Theme.Palette.surface, in: Circle())
                .shadow(color: Theme.Shadow.color, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    // MARK: - Flow

    private func flip(_ item: Item) {
        if isFlipped {
            // Impatient tap on the revealed name: skip the wait and move on.
            show((index + 1) % items.count)
            return
        }

        isFlipped = true
        Haptics.success()
        audio.speak(item)

        let currentGeneration = generation
        Task {
            try? await Task.sleep(for: .milliseconds(2200))
            // Only auto-advance if nothing else moved the deck meanwhile.
            guard generation == currentGeneration, isFlipped else { return }
            show((index + 1) % items.count)
        }
    }

    private func show(_ newIndex: Int) {
        generation += 1
        isFlipped = false
        progress.setFlashcardIndex(newIndex, for: pack.id)
    }
}
