import SwiftUI

/// Renders whatever an ``Item`` looks like.
///
/// Sits above ``ArtView`` so that flags — which are structural, wide, and sized
/// from the space available rather than from a square art dimension — get drawn by
/// ``FlagView`` without every mechanic needing to know that flags are special.
struct ItemArtView: View {
    let item: Item
    var size: CGFloat = 92
    var tint: Color = .white

    var body: some View {
        if let flag = item.flag {
            FlagView(design: flag)
                .frame(maxWidth: .infinity)
                // Keeps the pack colour visible as a frame around the flag. Without
                // it the flag reaches the tile edge and the category colour is gone.
                .padding(.horizontal, 14)
        } else {
            ArtView(art: item.art, size: size, tint: tint)
        }
    }
}
