import SwiftUI

/// Mechanic 01 — free tap-around.
///
/// There is no goal, no score, no round and no way to finish. Tap a thing, it
/// pops and says its name. This is where a two-year-old actually lives, and it
/// is the mechanic every other one is measured against: if Discover isn't fun,
/// nothing built on top of it will be.
///
/// **Everything fits on one screen.** No scrolling, ever. A two-year-old does
/// not know that content exists below the fold, and asking them to find it is
/// asking them to fail. That constraint is why the level system caps the item
/// pool rather than showing the whole pack.
struct DiscoverView: View {
    let pack: Pack
    let params: LevelParams

    @Environment(AudioService.self) private var audio
    @State private var activeItemID: Item.ID?

    private var items: [Item] { pack.items(for: params) }

    var body: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            ForEach(rows) { row in
                HStack(spacing: Theme.Metrics.minGap) {
                    ForEach(row.items) { item in
                        ItemTile(
                            item: item,
                            color: pack.color.color,
                            isActive: activeItemID == item.id
                        ) {
                            tap(item)
                        }
                    }
                    // Keep the last row's tiles the same width as every other
                    // row's rather than letting two items stretch across.
                    if row.items.count < columnCount {
                        ForEach(0 ..< (columnCount - row.items.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
        .onAppear {
            // Warm the players before the first tap, not on it.
            audio.prewarm(items.map(\.voiceClip))
            audio.prewarm(items.compactMap(\.effectClip))
        }
    }

    // MARK: - Layout

    private struct Row: Identifiable {
        let id: Int
        let items: [Item]
    }

    private var columnCount: Int { GridFit.columnCount(for: items.count) }

    private var rows: [Row] {
        GridFit.chunk(items, into: columnCount).enumerated().map(Row.init)
    }

    private func tap(_ item: Item) {
        activeItemID = item.id
        audio.speakThenEffect(item)

        // Let the tile settle back on its own. Nothing here can fail, so there
        // is no state to unwind — the child can hammer tiles as fast as they like.
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            if activeItemID == item.id { activeItemID = nil }
        }
    }
}
