import SwiftUI

/// Navigation for the whole app: home, a pack, or the sticker album.
///
/// Deliberately not a `NavigationStack`. There is no back chrome to learn, no
/// swipe-from-edge gesture a toddler triggers by accident, and no way to end up
/// three screens deep. Home is one tap from anywhere, always in the same corner.
struct RootView: View {
    @Environment(AudioService.self) private var audio
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var settings
    @Environment(UsageTracker.self) private var usage

    @State private var library: ContentLibrary?
    @State private var loadError: String?
    @State private var screen: Screen = .home
    @State private var isShowingGate = false
    @State private var isShowingParentZone = false

    private enum Screen: Equatable {
        case home
        case pack(String)
        case album
    }

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView(
                    "Content didn't load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else if let library {
                body(for: library)
                    .environment(library)
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .task(load)
    }

    @ViewBuilder
    private func body(for library: ContentLibrary) -> some View {
        ZStack {
            if usage.hasReachedLimit(settings.dailyLimitMinutes) {
                WindDownView { isShowingGate = true }
                    .transition(.opacity)
            } else {
                content(library)
            }

            if isShowingGate {
                ParentGateView {
                    isShowingGate = false
                    isShowingParentZone = true
                } onCancel: {
                    isShowingGate = false
                }
                .transition(.opacity)
            }
        }
        .animation(Motion.settle, value: isShowingGate)
        .animation(Motion.settle, value: usage.hasReachedLimit(settings.dailyLimitMinutes))
        .sheet(isPresented: $isShowingParentZone) {
            ParentZoneView(packs: library.packs) {
                isShowingParentZone = false
            }
        }
    }

    @ViewBuilder
    private func content(_ library: ContentLibrary) -> some View {
        let packs = availablePacks(library)

        ZStack {
            switch screen {
            case .home:
                HomeView(packs: packs) { pack in
                    screen = .pack(pack.id)
                } onAlbum: {
                    screen = .album
                } onParentGate: {
                    isShowingGate = true
                }
                .transition(transition)

            case .pack(let id):
                if let pack = packs.first(where: { $0.id == id }) {
                    PackView(pack: pack, params: LevelParams.params(for: settings.level)) {
                        screen = .home
                    }
                    .transition(transition)
                } else {
                    // The parent switched this pack off, or lowered the level,
                    // while the child was inside it. Fall back to home rather
                    // than showing an empty screen.
                    Color.clear.onAppear { screen = .home }
                }

            case .album:
                albumScreen.transition(transition)
            }
        }
        .animation(Motion.settle, value: screen)
    }

    /// Packs the child may see: available at this level, and not switched off.
    private func availablePacks(_ library: ContentLibrary) -> [Pack] {
        library.packs(for: settings.level).filter { settings.isEnabled($0) }
    }

    private var albumScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Button {
                    screen = .home
                } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                        .frame(width: 96, height: 96)
                        .background(Theme.Palette.surface, in: Circle())
                        .shadow(color: Theme.Shadow.color, radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Home")

                Text("My Stickers")
                    .font(Theme.TypeScale.title)
                    .foregroundStyle(Theme.Palette.ink)

                Spacer()
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.vertical, 18)

            StickerAlbumView()
        }
        .background(Theme.Palette.background)
    }

    private var transition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.97))
    }

    @Sendable
    private func load() async {
        do {
            library = ContentLibrary(packs: try ContentLoader.loadAll())
        } catch {
            loadError = error.localizedDescription
        }
    }
}
