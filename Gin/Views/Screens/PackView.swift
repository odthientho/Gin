import SwiftUI

/// The activity shell for one category.
///
/// Opening a pack drops straight into Discover rather than showing a menu of
/// games — a two-year-old should not have to choose an activity type, and a
/// submenu is a wall they cannot read their way past. The play button cycles to
/// the next game instead, so exploring is the default and games are opt-in.
struct PackView: View {
    let pack: Pack
    let params: LevelParams
    let onHome: () -> Void

    @Environment(ProgressStore.self) private var progress
    @Environment(AudioService.self) private var audio

    @State private var mechanic: Mechanic = .discover
    @State private var reward: (item: Item, isNew: Bool)?

    /// Mechanics that actually exist yet. A pack may declare one before it is
    /// built; listing them here is what keeps the play button from cycling into
    /// an empty screen.
    private static let implemented: [Mechanic] = [
        .discover, .findIt, .match, .dropIn, .count, .hearIt, .addTakeAway, .pattern,
        .trace, .flashcard, .logic, .clockRead, .clockFind
    ]

    private var available: [Mechanic] {
        let usable = pack.mechanics.filter { mechanic in
            guard Self.implemented.contains(mechanic) else { return false }
            // Hear It is not a game without real sound effects — it degrades into
            // Find It with extra steps, so hide it until the recordings exist.
            if mechanic == .hearIt {
                return pack.items.contains { audio.hasClip($0.effectClip) }
            }
            return true
        }
        return usable.isEmpty ? [.discover] : usable
    }

    /// The mechanic actually shown.
    ///
    /// `mechanic` starts at `.discover` because that is where nearly every
    /// pack should open. But a pack need not offer it — Writing declares only
    /// `trace` — and falling through to Discover then shows a tile grid the
    /// pack was never meant to have. So the displayed mechanic is always
    /// resolved against what this pack actually offers.
    private var resolvedMechanic: Mechanic {
        available.contains(mechanic) ? mechanic : (available.first ?? .discover)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                current
            }
            .background(Theme.Palette.background)

            if let reward {
                RewardOverlay(
                    item: reward.item,
                    color: pack.color.color,
                    isNew: reward.isNew
                ) {
                    self.reward = nil
                }
                .transition(.opacity)
            }
        }
        .animation(Motion.settle, value: reward?.item.id)
    }

    @ViewBuilder
    private var current: some View {
        switch resolvedMechanic {
        case .findIt:
            FindItView(pack: pack, params: params, onRoundComplete: award)
        case .match:
            MatchView(pack: pack, params: params, onRoundComplete: award)
        case .dropIn:
            DropInView(pack: pack, params: params, onRoundComplete: award)
        case .count:
            CountTapView(pack: pack, params: params, onRoundComplete: award)
        case .hearIt:
            HearItView(pack: pack, params: params, onRoundComplete: award)
        case .addTakeAway:
            AddTakeAwayView(pack: pack, params: params, onRoundComplete: award)
        case .pattern:
            PatternsView(pack: pack, params: params, onRoundComplete: award)
        case .trace:
            TraceView(pack: pack, params: params, onRoundComplete: award)
        case .flashcard:
            FlashcardView(pack: pack, params: params)
        case .logic:
            LogicView(pack: pack, params: params, onRoundComplete: award)
        case .clockRead:
            ClockView(pack: pack, params: params, direction: .readClock,
                      onRoundComplete: award)
        case .clockFind:
            ClockView(pack: pack, params: params, direction: .findClock,
                      onRoundComplete: award)
        default:
            DiscoverView(pack: pack, params: params)
        }
    }

    private var header: some View {
        HStack(spacing: 20) {
            // Home is always in the same corner, always one tap away, on every
            // screen. It is the only navigation a child needs to learn.
            circleButton(systemName: "house.fill", label: "Home", action: onHome)

            Text(pack.title)
                .font(Theme.TypeScale.title)
                .foregroundStyle(Theme.Palette.ink)

            Spacer()

            if available.count > 1 {
                circleButton(
                    systemName: mechanic == .discover ? "play.fill" : "arrow.triangle.2.circlepath",
                    label: "Next game",
                    tint: pack.color.color,
                    action: { cycleMechanic() }
                )
            }

            circleButton(
                systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: audio.isMuted ? "Unmute" : "Mute"
            ) {
                audio.isMuted.toggle()
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.vertical, 18)
    }

    private func circleButton(
        systemName: String,
        label: String,
        tint: Color = Theme.Palette.ink,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 96, height: 96)
                .background(Theme.Palette.surface, in: Circle())
                .shadow(color: Theme.Shadow.color, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Flow

    /// - Parameter skippingStudy: when true, flashcards are passed over.
    ///   Flashcards are a study deck rather than a game, so a finished round
    ///   should hand off to another *game* instead of dumping the child back
    ///   into browsing. The play button passes false, so tapping through still
    ///   reaches the deck deliberately.
    private func cycleMechanic(skippingStudy: Bool = false) {
        guard available.count > 1 else { return }

        let start = available.firstIndex(of: resolvedMechanic) ?? -1
        // Walk forward until something acceptable turns up. Bounded by the
        // number of mechanics, so it terminates even if every one is skippable.
        for step in 1 ... available.count {
            let candidate = available[(start + step) % available.count]
            if skippingStudy && candidate == .flashcard { continue }
            mechanic = candidate
            return
        }
    }

    private func award(_ item: Item) {
        let isNew = !progress.hasEarned(item.id)
        progress.award(item.id)
        reward = (item, isNew)

        // A finished round hands off to a different game. Switching now, while
        // the reward is still covering the screen, means the child looks up from
        // the sticker into something new rather than watching the swap happen.
        //
        // Packs with a single mechanic (Writing) simply carry on — `cycleMechanic`
        // is a no-op there, which is the right behaviour, not an oversight.
        cycleMechanic(skippingStudy: true)
    }
}
