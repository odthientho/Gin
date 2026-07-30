import SwiftUI

/// Renders an ``Art`` value however that particular item is drawn.
///
/// The point of routing every picture through here is that a pack can mix
/// code-drawn geometry with licensed illustration, and a mechanic never needs to
/// know which it is holding.
struct ArtView: View {
    let art: Art
    var size: CGFloat = 92
    /// Shapes and numerals take their color from the surface behind them.
    var tint: Color = .white

    var body: some View {
        switch art.kind {
        case .emoji:
            Text(art.value)
                .font(.system(size: size))

        case .asset:
            Image(art.value)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)

        case .geometry:
            GeometryArtView(value: art.value, size: size, tint: tint)
        }
    }
}
