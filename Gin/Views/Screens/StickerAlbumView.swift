import SwiftUI

/// The sticker album — mechanic 07, and the only place progress is visible.
///
/// There is no tray and no "place this sticker" step. Every earned sticker is
/// already on the page, arranged along the bottom the first time, and the child
/// drags them wherever they like. Removing the tray removes a whole concept a
/// two-year-old would otherwise have to be taught.
struct StickerAlbumView: View {
    @Environment(ContentLibrary.self) private var library
    @Environment(ProgressStore.self) private var progress
    @Environment(AudioService.self) private var audio

    /// In-flight drag offsets, cleared once a drag commits to a placement.
    @State private var dragOffsets: [String: CGSize] = [:]

    private let stickerSize: CGFloat = 116

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                scene

                if progress.earnedStickerIDs.isEmpty {
                    emptyState
                } else {
                    ForEach(progress.earnedStickerIDs, id: \.self) { id in
                        if let item = library.item(id) {
                            sticker(item, in: geometry.size)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { seedPlacements(in: geometry.size) }
        }
    }

    // MARK: - Pieces

    private var scene: some View {
        LinearGradient(
            colors: [
                Theme.Palette.sky.opacity(0.28),
                Theme.Palette.background,
                Theme.Palette.sun.opacity(0.20)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Text("🎁")
                .font(.system(size: 120))
            Text("Play a game to win stickers")
                .font(Theme.TypeScale.label)
                .foregroundStyle(Theme.Palette.inkSoft)
        }
    }

    private func sticker(_ item: Item, in size: CGSize) -> some View {
        let placement = progress.placement(for: item.id) ?? StickerPlacement(x: 0.5, y: 0.5)
        let offset = dragOffsets[item.id] ?? .zero
        let base = CGPoint(x: placement.x * size.width, y: placement.y * size.height)

        return ItemArtView(item: item, size: 84)
            .frame(width: stickerSize, height: stickerSize)
            .background(Theme.Palette.surface, in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 5))
            .shadow(color: Theme.Shadow.color,
                    radius: offset == .zero ? 8 : 20,
                    y: offset == .zero ? 4 : 12)
            .scaleEffect(offset == .zero ? 1 : 1.12)
            .position(x: base.x + offset.width, y: base.y + offset.height)
            .animation(Motion.settle, value: offset == .zero)
            .gesture(dragGesture(for: item, in: size, from: placement))
            .accessibilityLabel(item.name)
    }

    private func dragGesture(
        for item: Item,
        in size: CGSize,
        from placement: StickerPlacement
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragOffsets[item.id] = value.translation
            }
            .onEnded { value in
                // A tap with no meaningful movement should say the word rather
                // than nudge the sticker a pixel.
                let didMove = abs(value.translation.width) > 6
                    || abs(value.translation.height) > 6

                if didMove {
                    let newX = (placement.x * size.width + value.translation.width) / size.width
                    let newY = (placement.y * size.height + value.translation.height) / size.height
                    progress.place(item.id, at: StickerPlacement(x: newX, y: newY))
                } else {
                    audio.speak(item)
                }
                dragOffsets[item.id] = nil
            }
    }

    // MARK: - Placement

    /// Gives any sticker without a placement a spot along the bottom, so nothing
    /// is ever invisible or stacked under something else.
    private func seedPlacements(in size: CGSize) {
        let unplaced = progress.unplacedStickerIDs
        guard !unplaced.isEmpty, size.width > 0 else { return }

        let perRow = max(1, Int((size.width - stickerSize) / (stickerSize + 20)))

        for (index, id) in unplaced.enumerated() {
            let column = index % perRow
            let row = index / perRow
            let x = (Double(column) + 0.8) * Double(stickerSize + 20) / Double(size.width)
            let y = 0.86 - Double(row) * 0.16
            progress.place(id, at: StickerPlacement(x: x, y: y))
        }
    }
}
