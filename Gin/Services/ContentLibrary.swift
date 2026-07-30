import Observation

/// The loaded content, plus the lookups the rest of the app needs.
///
/// Held once at the root and passed through the environment. Packs are static
/// after launch — nothing here ever changes at runtime.
@MainActor
@Observable
final class ContentLibrary {
    let packs: [Pack]
    private let itemIndex: [Item.ID: Item]

    init(packs: [Pack]) {
        self.packs = packs
        self.itemIndex = Dictionary(
            packs.flatMap(\.items).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Resolves an item id back to the item — how an earned sticker knows what
    /// it is a picture of.
    func item(_ id: Item.ID) -> Item? { itemIndex[id] }

    /// The packs a child at this level is allowed to see. Math and Flags simply
    /// are not on the home screen for a two-year-old.
    func packs(for level: Level) -> [Pack] {
        packs.filter { $0.isAvailable(at: level) }
    }
}
