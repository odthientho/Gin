import SwiftUI

/// Draws a flag from its ``FlagDesign``.
///
/// Prefers a real illustration when the design names one and it is in the bundle;
/// otherwise draws the bands and emblem. That fallback is why the Flags pack is
/// playable before the intricate flags' artwork has been bought — an approximate
/// Brazil is better than a missing Brazil, and the switch happens automatically
/// the moment the asset lands.
struct FlagView: View {
    let design: FlagDesign

    /// Deliberately size-agnostic: the flag fills whatever width it is given at a
    /// fixed 3:2 aspect. An explicit width meant callers had to guess how much
    /// room a tile had, and flags ended up overhanging their own tile — which hid
    /// the pack colour that tells a pre-reader what category they are in.
    var body: some View {
        Group {
            if let assetName = design.assetName, hasAsset(assetName) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                bands.overlay { emblemView }
            }
        }
        .aspectRatio(3.0 / 2.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.black.opacity(0.14), lineWidth: 2)
        }
        .shadow(color: Theme.Shadow.color, radius: 10, y: 5)
    }

    // MARK: - Pieces

    @ViewBuilder
    private var bands: some View {
        let colors = design.bands.map { Color(hexString: $0) ?? .gray }

        if design.orientation == .horizontal {
            VStack(spacing: 0) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    color
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    color
                }
            }
        }
    }

    @ViewBuilder
    private var emblemView: some View {
        if let emblem = design.emblem {
            // Sized from the rendered flag rather than a fixed dimension, so an
            // emblem stays correctly proportioned at any tile size.
            GeometryReader { geometry in
                let color = Color(hexString: emblem.color) ?? .white
                let diameter = geometry.size.height * emblem.relativeSize

                switch emblem.kind {
                case .star:
                    Star()
                        .fill(color)
                        .frame(width: diameter, height: diameter)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                case .circle:
                    Circle()
                        .fill(color)
                        .frame(width: diameter, height: diameter)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                case .cross:
                    // A cross spans the whole flag; its bars are placed by the shape.
                    FlagCross(
                        thickness: 0.2,
                        verticalOffset: emblem.crossOffset ?? 0.36
                    )
                    .fill(color)
                }
            }
        }
    }

    private func hasAsset(_ name: String) -> Bool {
        UIImage(named: name) != nil
    }
}
