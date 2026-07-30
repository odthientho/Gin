import SwiftUI

/// One tappable thing. The single most-touched surface in the app, so every
/// number in here is a design token rather than a literal.
struct ItemTile: View {
    let item: Item
    let color: Color
    /// True while this item is the one being spoken, which lifts it above the rest.
    let isActive: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            ItemArtView(item: item)
            Text(item.name)
                .font(Theme.TypeScale.label)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
        }
        // Fills whatever cell the grid hands it, never below the touch-target floor.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: Theme.Metrics.minTouchTarget,
               minHeight: Theme.Metrics.minTouchTarget)
        .background {
            RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                .fill(color)
                .overlay(alignment: .bottom) {
                    // A darker lip along the bottom edge reads as physical depth,
                    // which is what makes a flat rectangle look pressable.
                    Rectangle()
                        .fill(.black.opacity(0.13))
                        .frame(height: 16)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner,
                                            style: .continuous))
        }
        .shadow(color: Theme.Shadow.color,
                radius: isActive ? Theme.Shadow.radius * 1.6 : Theme.Shadow.radius,
                y: isActive ? Theme.Shadow.y * 1.4 : Theme.Shadow.y)
        .scaleEffect(isActive && !reduceMotion ? 1.08 : 1)
        .animation(Motion.pop, value: isActive)
        .toddlerTap(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(.isButton)
    }
}
