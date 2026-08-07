import Foundation

enum ContentError: LocalizedError {
    case packNotFound(String)
    case packUnreadable(String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .packNotFound(let id):
            "Content pack '\(id).json' is not in the app bundle."
        case .packUnreadable(let id, let underlying):
            "Content pack '\(id).json' could not be read: \(underlying)"
        }
    }
}

/// Loads content packs from bundled JSON.
///
/// All content is static and shipped in the binary — there is no network call
/// anywhere in Gin, which is what makes the Kids Category privacy story trivial.
/// Authoring a new category means adding a `.json` file here and listing its id
/// in ``packIdentifiers``; no Swift changes.
enum ContentLoader {

    /// The packs that ship, in the order they appear on the home screen.
    /// Level gating is a property of each pack, not of this list — everything
    /// is loaded, then filtered by the parent's chosen level at display time.
    static let packIdentifiers: [String] = [
        // Level 1
        "animals",
        "colors",
        "shapes",
        "numbers",
        "vehicles",
        // Level 2 — gated by each pack's own minLevel, not by this list.
        "letters",
        "feelings",
        "opposites",
        // Level 3
        "math",
        "flags",
        "patterns",
        "writing",
        "logic",
        "clock"
    ]

    /// Decodes every pack. Throws rather than skipping a bad file — a content
    /// typo should stop the app in development, not silently ship a half-empty
    /// category to a child.
    static func loadAll(from bundle: Bundle = .main) throws -> [Pack] {
        try packIdentifiers.map { try load($0, from: bundle) }
    }

    static func load(_ id: String, from bundle: Bundle = .main) throws -> Pack {
        // Depending on whether the Resources folder lands as a group or a folder
        // reference, the file is either nested under Packs/ or flattened to the
        // bundle root. Check both so the build configuration can't break content.
        let url = bundle.url(forResource: id, withExtension: "json", subdirectory: "Packs")
            ?? bundle.url(forResource: id, withExtension: "json")

        guard let url else { throw ContentError.packNotFound(id) }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Pack.self, from: data)
        } catch {
            throw ContentError.packUnreadable(id, underlying: error)
        }
    }
}
