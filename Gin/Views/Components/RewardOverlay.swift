import SwiftUI

/// The sticker celebration.
///
/// This is the *only* progression in Gin — no stars, no score, no levels
/// completed. Collection motivates at this age; ranking does not, and ranking
/// implies the possibility of doing badly, which this app does not have.
///
/// **It clears itself.** A reward that waits for a tap is a gate, and a gate is
/// exactly what a child in the middle of playing does not need. It shows for a
/// couple of seconds over a game that is already moving on underneath, and a tap
/// anywhere skips it.
struct RewardOverlay: View {
    let item: Item
    let color: Color
    let isNew: Bool
    let onDismiss: () -> Void

    /// Long enough to see what was earned, short enough not to break the rhythm.
    private let visibleFor = Duration.milliseconds(2400)

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 28) {
                ZStack {
                    ForEach(0 ..< 8, id: \.self) { index in
                        Capsule()
                            .fill(confettiColor(index))
                            .frame(width: 16, height: 44)
                            .offset(y: hasAppeared && !reduceMotion ? -190 : 0)
                            .rotationEffect(.degrees(Double(index) / 8 * 360))
                            .opacity(hasAppeared ? 0 : 1)
                            .animation(
                                .easeOut(duration: 0.9).delay(Double(index) * 0.02),
                                value: hasAppeared
                            )
                    }

                    ItemArtView(item: item, size: 150)
                        .frame(width: 260, height: 260)
                        .background(Theme.Palette.surface, in: Circle())
                        .overlay(Circle().strokeBorder(color, lineWidth: 10))
                        .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
                        .scaleEffect(hasAppeared ? 1 : 0.4)
                        .animation(Motion.pop, value: hasAppeared)
                }

                Text(isNew ? "You got \(item.name)!" : "\(item.name) again!")
                    .font(Theme.TypeScale.title)
                    .foregroundStyle(.white)

                Button(action: onDismiss) {
                    Text("More")
                        .font(Theme.TypeScale.label)
                        .foregroundStyle(Theme.Palette.ink)
                        .frame(minWidth: 220, minHeight: 96)
                        .background(Theme.Palette.surface, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            hasAppeared = true
            try? await Task.sleep(for: visibleFor)
            // Cancelled automatically if a tap dismissed it first.
            guard !Task.isCancelled else { return }
            onDismiss()
        }
        .accessibilityAddTraits(.isModal)
    }

    private func confettiColor(_ index: Int) -> Color {
        let palette = [
            Theme.Palette.mango, Theme.Palette.berry, Theme.Palette.sky,
            Theme.Palette.grape, Theme.Palette.leaf, Theme.Palette.sun
        ]
        return palette[index % palette.count]
    }
}
