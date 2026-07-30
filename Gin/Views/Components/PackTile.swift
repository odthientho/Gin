import SwiftUI

/// A category on the home screen.
///
/// Carries its color permanently, which is how a pre-reader recognizes Animals
/// before they can read the word "Animals".
struct PackTile: View {
    let pack: Pack
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(pack.icon)
                .font(.system(size: 96))
            Text(pack.title)
                .font(Theme.TypeScale.label)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: Theme.Metrics.minTouchTarget,
               minHeight: Theme.Metrics.minTouchTarget)
        .background {
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner, style: .continuous)
                .fill(pack.color.color)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.black.opacity(0.13))
                        .frame(height: 18)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner,
                                            style: .continuous))
        }
        .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, y: Theme.Shadow.y)
        // Navigates, so it must act on touch-up — see ToddlerTapFeedback.
        .toddlerTap(firesOnTouchDown: false, perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(pack.title)
        .accessibilityAddTraits(.isButton)
    }
}
