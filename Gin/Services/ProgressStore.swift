import CoreGraphics
import Foundation
import Observation

/// Where a child dragged a sticker, in **normalized** album coordinates (0...1).
///
/// Normalized rather than absolute so a placement survives a different iPad, a
/// different album size, or a layout change. An absolute point would silently
/// move every sticker the first time the scene resized.
struct StickerPlacement: Codable, Sendable, Equatable {
    var x: Double
    var y: Double

    var point: CGPoint { CGPoint(x: x, y: y) }

    init(x: Double, y: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }

    init(_ point: CGPoint) { self.init(x: point.x, y: point.y) }
}

private struct ProgressSnapshot: Codable {
    var earnedStickerIDs: [String] = []
    var placements: [String: StickerPlacement] = [:]
    var writingIndex: Int = 0
    /// Optional deliberately: synthesized Codable *throws* on a missing key even
    /// when the property has a default, so a required new field would make every
    /// pre-upgrade progress file "corrupt" and silently wipe a child's stickers.
    var flashcardIndices: [String: Int]?
    /// Hardest reasoning rung unlocked, per pack. Optional for the same reason.
    var logicTiers: [String: Int]?
    /// Same Codable caution. Pack id → items proven in a quiz, which is what
    /// advances a grouped pack to its next learning group.
    var masteredIDs: [String: [String]]?
}

/// Everything the app remembers between launches.
///
/// Deliberately *not* SwiftData. The whole payload is a list of ids and a few
/// points — there are no queries, no relationships and no sync, so SwiftData's
/// value goes unused while its ModelContainer and concurrency surface still cost
/// something. A Codable snapshot written to Application Support is the right
/// size for this, and swapping it out later touches only this file.
@MainActor
@Observable
final class ProgressStore {

    private(set) var earnedStickerIDs: [String] = []
    private(set) var placements: [String: StickerPlacement] = [:]

    /// Which glyph the child reached in the writing pack, so they resume
    /// there instead of re-tracing a vertical line every launch.
    private(set) var writingIndex: Int = 0

    /// Per-pack flashcard positions, keyed by pack id.
    private(set) var flashcardIndices: [String: Int] = [:]

    /// Hardest reasoning rung unlocked, per pack. Rungs never lock again.
    private(set) var logicTiers: [String: Int] = [:]

    /// Per-pack ids the child has answered correctly in a quiz. This is what
    /// "learning the first 25" means operationally: the next group of a grouped
    /// pack unlocks when the current group is covered here.
    private(set) var masteredIDs: [String: Set<String>] = [:]

    private let fileURL: URL?

    init(fileURL: URL? = ProgressStore.defaultFileURL()) {
        self.fileURL = fileURL
        load()
    }

    // MARK: - Reads

    func hasEarned(_ id: String) -> Bool { earnedStickerIDs.contains(id) }

    func placement(for id: String) -> StickerPlacement? { placements[id] }

    /// Stickers earned but not yet dragged anywhere — the ones the album shows
    /// waiting in the tray.
    var unplacedStickerIDs: [String] {
        earnedStickerIDs.filter { placements[$0] == nil }
    }

    // MARK: - Writes

    /// Awards a sticker. Earning the same one twice is a no-op rather than a
    /// duplicate: a child who loves cows will land on the cow repeatedly, and
    /// the album should not fill up with eight identical cows.
    func award(_ id: String) {
        guard !earnedStickerIDs.contains(id) else { return }
        earnedStickerIDs.append(id)
        save()
    }

    func place(_ id: String, at placement: StickerPlacement) {
        guard earnedStickerIDs.contains(id) else { return }
        placements[id] = placement
        save()
    }

    func setWritingIndex(_ index: Int) {
        guard index >= 0, index != writingIndex else { return }
        writingIndex = index
        save()
    }

    /// Where the flashcard deck for a pack is open to, so a returning child
    /// continues from Croatia rather than starting over at France every launch.
    func flashcardIndex(for packID: String) -> Int {
        flashcardIndices[packID] ?? 0
    }

    func setFlashcardIndex(_ index: Int, for packID: String) {
        guard index >= 0, flashcardIndices[packID] ?? 0 != index else { return }
        flashcardIndices[packID] = index
        save()
    }

    /// The difficulty rung a child has reached in a pack that has a ladder.
    ///
    /// Defaults to the first rung rather than zero, so a fresh child starts at
    /// the easiest puzzle rather than an invalid one.
    ///
    /// The stored key is still `logicTiers` — Logic was the first pack with a
    /// ladder and Clock now shares the mechanism. Renaming the key would read as
    /// tidier and would silently reset every child's Logic progress on upgrade,
    /// which is not a trade worth making for a nicer name.
    func tier(for packID: String) -> Int {
        max(1, logicTiers[packID] ?? 1)
    }

    /// Only ever raises. A rung, once reached, stays reached — there are no fail
    /// states in this app, and demoting a child would be the sharpest one.
    func setTier(_ tier: Int, for packID: String) {
        guard tier > self.tier(for: packID) else { return }
        logicTiers[packID] = tier
        save()
    }

    func mastered(in packID: String) -> Set<String> {
        masteredIDs[packID] ?? []
    }

    /// Records a correct quiz answer. Mastery only accumulates — a later wrong
    /// tap never takes it back, because nothing in Gin is ever lost.
    func recordMastered(_ itemID: String, in packID: String) {
        guard !mastered(in: packID).contains(itemID) else { return }
        masteredIDs[packID, default: []].insert(itemID)
        save()
    }

    /// Used by the parent zone in Phase 5.
    func resetAll() {
        earnedStickerIDs = []
        placements = [:]
        save()
    }

    // MARK: - Persistence

    private static func defaultFileURL() -> URL? {
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return directory.appendingPathComponent("gin-progress.json")
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        guard let snapshot = try? JSONDecoder().decode(ProgressSnapshot.self, from: data) else {
            // Corrupt progress is not worth crashing a child's app over. Start
            // fresh; the worst case is an empty sticker album.
            return
        }
        earnedStickerIDs = snapshot.earnedStickerIDs
        placements = snapshot.placements
        writingIndex = snapshot.writingIndex
        flashcardIndices = snapshot.flashcardIndices ?? [:]
        logicTiers = snapshot.logicTiers ?? [:]
        masteredIDs = (snapshot.masteredIDs ?? [:]).mapValues(Set.init)
    }

    private func save() {
        guard let fileURL else { return }
        let snapshot = ProgressSnapshot(
            earnedStickerIDs: earnedStickerIDs,
            placements: placements,
            writingIndex: writingIndex,
            flashcardIndices: flashcardIndices,
            logicTiers: logicTiers,
            masteredIDs: masteredIDs.mapValues { Array($0).sorted() }
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
