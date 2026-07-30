import SwiftUI

/// The home screen: every category, plus the sticker album.
///
/// One screen, no scrolling, no submenus. Only the packs available at the
/// current level appear, so a two-year-old's home screen simply does not contain
/// Math or Flags — they are not greyed out or locked, they are absent, because a
/// locked thing is a thing to cry about.
struct HomeView: View {
    let packs: [Pack]
    let onSelect: (Pack) -> Void
    let onAlbum: () -> Void
    let onParentGate: () -> Void

    @Environment(AudioService.self) private var audio
    @Environment(ProgressStore.self) private var progress

    private var tileCount: Int { packs.count + 1 }
    private var columnCount: Int { GridFit.columnCount(for: tileCount) }

    var body: some View {
        VStack(spacing: 0) {
            header
            grid
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
    }

    private var header: some View {
        HStack {
            Text("Gin")
                .font(Theme.TypeScale.display)
                .foregroundStyle(Theme.Palette.ink)

            Spacer()

            // Small, low-contrast and in the corner: an adult finds it instantly,
            // and it does not read as a toy worth poking. The gate behind it is
            // what actually protects the settings.
            Button(action: onParentGate) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.Palette.inkSoft.opacity(0.6))
                    .frame(width: 76, height: 76)
                    .background(Theme.Palette.surface.opacity(0.7), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Grown-ups")

            Button {
                audio.isMuted.toggle()
            } label: {
                Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink)
                    .frame(width: 96, height: 96)
                    .background(Theme.Palette.surface, in: Circle())
                    .shadow(color: Theme.Shadow.color, radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audio.isMuted ? "Unmute" : "Mute")
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private var grid: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Theme.Metrics.minGap) {
                    ForEach(row, id: \.id) { tile in
                        switch tile {
                        case .pack(let pack):
                            PackTile(pack: pack) { onSelect(pack) }
                        case .album:
                            albumTile
                        }
                    }
                    if row.count < columnCount {
                        ForEach(0 ..< (columnCount - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, Theme.Metrics.screenPadding)
    }

    private var albumTile: some View {
        VStack(spacing: 12) {
            Text("⭐️")
                .font(.system(size: 96))
            Text(progress.earnedStickerIDs.isEmpty
                 ? "Stickers"
                 : "Stickers · \(progress.earnedStickerIDs.count)")
                .font(Theme.TypeScale.label)
                .foregroundStyle(Theme.Palette.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: Theme.Metrics.minTouchTarget,
               minHeight: Theme.Metrics.minTouchTarget)
        .background {
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner, style: .continuous)
                .fill(Theme.Palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner, style: .continuous)
                        .strokeBorder(Theme.Palette.hairline, lineWidth: 4)
                }
        }
        .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, y: Theme.Shadow.y)
        .toddlerTap(firesOnTouchDown: false, perform: onAlbum)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sticker album")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Layout

    private enum Tile: Identifiable {
        case pack(Pack)
        case album

        var id: String {
            switch self {
            case .pack(let pack): pack.id
            case .album: "__album"
            }
        }
    }

    private var rows: [[Tile]] {
        GridFit.chunk(packs.map(Tile.pack) + [.album], into: columnCount)
    }
}
