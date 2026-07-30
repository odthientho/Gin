import CoreGraphics
import Foundation

/// One activity type. Mechanics are the reason this app is finishable: seven
/// packs share eight pieces of code, so adding a category is a JSON file and an
/// art folder rather than a new screen.
enum Mechanic: String, Codable, Sendable, CaseIterable {
    case discover      // free tap-around, no goal
    case findIt        // "Where is the cow?" — also Flags, with promptType flipped
    case match         // three pairs, face-up first
    case dropIn        // drag to a silhouette, forgiving snap
    case count         // tap each object once, one-to-one correspondence
    case hearIt        // a sound plays, pick the picture
    case stickerScene  // open-ended sandbox
    case addTakeAway   // objects arrive or leave, then pick a numeral
    case pattern       // AB / AAB sequencing — what comes next
    case trace         // handwriting: follow the dashed glyph with a Pencil
    case flashcard     // learn-first deck: big picture, tap to flip and hear it
}

/// How an item is drawn.
///
/// Half of Gin's content is geometry — shapes, colors, numerals, patterns and
/// most flags are cheaper, sharper and more consistent drawn in code than
/// shipped as images. The other half needs real illustration. This lets a pack
/// mix both, and lets Phase 1 run entirely on emoji placeholders.
struct Art: Codable, Sendable, Hashable {
    enum Kind: String, Codable, Sendable {
        case emoji     // placeholder through Phase 3; never ships
        case asset     // a licensed illustration in the bundle
        case geometry  // drawn by a SwiftUI Shape, keyed by `value`
    }

    var kind: Kind
    var value: String
}

/// An emblem sitting on top of a flag's bands.
struct FlagEmblem: Codable, Sendable, Hashable {
    enum Kind: String, Codable, Sendable {
        case star, circle, cross
    }

    var kind: Kind
    /// `#RRGGBB`.
    var color: String
    /// Diameter as a fraction of the flag's short side.
    var relativeSize: Double
    /// Where a cross's vertical bar sits across the width. Ignored by other kinds.
    var crossOffset: Double?
}

/// How to draw a flag.
///
/// Most flags are bands plus an optional emblem, which is genuinely cheaper and
/// sharper as geometry than as image files — and it means adding twenty more
/// countries is a JSON edit.
///
/// The intricate ones are not reasonably hand-codable (an eagle, a chakra, fifty
/// stars). Those carry an ``assetName``; the renderer prefers the illustration
/// when it is in the bundle and falls back to the bands as an approximation until
/// the art is bought, so the pack stays playable in the meantime.
struct FlagDesign: Codable, Sendable, Hashable {
    enum Orientation: String, Codable, Sendable {
        case horizontal, vertical
    }

    /// `#RRGGBB` bands, equal width, in order.
    var bands: [String]
    var orientation: Orientation
    var emblem: FlagEmblem?
    var assetName: String?

    init(
        bands: [String],
        orientation: Orientation = .horizontal,
        emblem: FlagEmblem? = nil,
        assetName: String? = nil
    ) {
        self.bands = bands
        self.orientation = orientation
        self.emblem = emblem
        self.assetName = assetName
    }
}

/// A single thing a child can learn: one animal, one shape, one flag.
struct Item: Codable, Sendable, Hashable, Identifiable {
    var id: String
    /// The word itself. Shown as text for the adult; always *spoken* for the child.
    var name: String
    var art: Art
    /// Filename of the recorded pronunciation, without extension.
    /// Falls back to synthesized speech until the real recordings exist.
    var voiceClip: String
    /// An optional non-speech sound: a moo, an engine, a siren.
    var effectClip: String?
    /// Free-form grouping ("farm", "ocean") used to build themed rounds.
    var tags: [String]
    /// Present only on flag items.
    var flag: FlagDesign?
    /// Present only on writing items — the strokes a child follows.
    var trace: GlyphTrace?

    init(
        id: String,
        name: String,
        art: Art,
        voiceClip: String,
        effectClip: String? = nil,
        tags: [String] = [],
        flag: FlagDesign? = nil,
        trace: GlyphTrace? = nil
    ) {
        self.id = id
        self.name = name
        self.art = art
        self.voiceClip = voiceClip
        self.effectClip = effectClip
        self.tags = tags
        self.flag = flag
        self.trace = trace
    }
}

/// A category: Animals, Shapes, Flags & Countries.
struct Pack: Codable, Sendable, Hashable, Identifiable {
    var id: String
    var title: String
    /// Owned permanently and across every level, so a pre-reader recognizes
    /// the category by color before they can read its name.
    var color: PackColor
    /// Emoji shown on the home tile. Replaced by real art in Phase 3.
    var icon: String
    /// The youngest level this pack appears at. Math and Flags are `.big`;
    /// everything a two-year-old should see is `.little`.
    var minLevel: Level
    var mechanics: [Mechanic]
    /// Overrides the level's item-pool cap when present. Most packs want the cap
    /// (a two-year-old meets six animals, not sixteen); Flags is the one pack
    /// whose entire point is breadth, so it keeps all 195 countries in rotation.
    var poolSize: Int?
    /// Splits the pack into learning groups of this many items, unlocked in
    /// order. Flags uses 25: a child studies the 25 most familiar flags on
    /// repeat, and the next 25 arrive only once each of the current group has
    /// been answered correctly in a quiz. Absent on packs small enough to learn
    /// whole.
    var groupSize: Int?
    /// Declares that this pack's questions can be posed the other way round —
    /// showing the picture and asking for the name. Data-driven because nothing
    /// structural distinguishes a flag item any more; an emoji flag looks like
    /// any other emoji to the model.
    var visualPrompt: Bool?
    var items: [Item]

    func isAvailable(at level: Level) -> Bool { level >= minLevel }

    /// Whether this pack can pose its questions the other way round. The old
    /// geometry-flag check is kept as a fallback for any pack that still ships
    /// drawn flag designs.
    var supportsVisualPrompt: Bool {
        visualPrompt ?? items.contains { $0.flag != nil }
    }

    /// The subset of items in play at a given level.
    func items(for params: LevelParams) -> [Item] {
        Array(items.prefix(poolSize ?? params.itemPoolSize))
    }

    // MARK: - Learning groups

    /// The pool divided into groups of ``groupSize``, in pack order. A pack
    /// without a group size is one group: learn it whole.
    func learningGroups(for params: LevelParams) -> [[Item]] {
        let pool = items(for: params)
        guard let groupSize, groupSize > 0, groupSize < pool.count else { return [pool] }
        return stride(from: 0, to: pool.count, by: groupSize).map { start in
            Array(pool[start ..< min(start + groupSize, pool.count)])
        }
    }

    /// The group currently being learned: the first whose items are not all
    /// mastered. A fully mastered pack stays on its last group rather than
    /// running out of things to show.
    func currentGroup(mastered: Set<Item.ID>, for params: LevelParams) -> [Item] {
        let groups = learningGroups(for: params)
        return groups.first { group in
            group.contains { !mastered.contains($0.id) }
        } ?? groups[groups.count - 1]
    }

    /// Every item the child has reached: all groups up to and including the
    /// current one. Quizzes draw from this window, so earlier groups stay in
    /// circulation instead of being learned and forgotten.
    func unlockedItems(mastered: Set<Item.ID>, for params: LevelParams) -> [Item] {
        let groups = learningGroups(for: params)
        var unlocked: [Item] = []
        for group in groups {
            unlocked.append(contentsOf: group)
            // Stop after the first incomplete group — that one is the frontier.
            if group.contains(where: { !mastered.contains($0.id) }) { break }
        }
        return unlocked
    }
}
