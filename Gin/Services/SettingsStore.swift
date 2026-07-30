import Foundation
import Observation

private struct SettingsSnapshot: Codable {
    var level: Level = .little
    var disabledPackIDs: [String] = []
    /// Minutes per day, or nil for no limit.
    var dailyLimitMinutes: Int?
    var pencilOnlyWriting: Bool = true
}

/// Everything the parent controls.
///
/// All of it lives behind the parental gate, and none of it is reachable by a
/// child. Persisted the same way progress is, and for the same reason: this is a
/// handful of values, not a database.
@MainActor
@Observable
final class SettingsStore {

    /// Which level the app is running at. The single most consequential setting —
    /// it decides whether Math and Flags exist at all.
    var level: Level = .little {
        didSet { save() }
    }

    /// Packs the parent has switched off. A child never sees these; they are
    /// absent from home rather than locked, because a locked tile is a tile to
    /// cry about.
    var disabledPackIDs: Set<String> = [] {
        didSet { save() }
    }

    /// Minutes of use per day before the wind-down. Nil means no limit.
    var dailyLimitMinutes: Int? {
        didSet { save() }
    }

    /// Whether the writing canvas ignores fingers.
    ///
    /// On by default, because palm rejection is the entire reason to use
    /// PencilKit here — a child rests their whole hand on the glass. Turn it
    /// off when the Pencil is flat or missing and a finger should draw.
    var pencilOnlyWriting: Bool = true {
        didSet { save() }
    }

    static let limitOptions: [Int?] = [nil, 10, 15, 20, 30, 45]

    private let fileURL: URL?
    private var isLoading = false

    init(fileURL: URL? = SettingsStore.defaultFileURL()) {
        self.fileURL = fileURL
        load()
    }

    func isEnabled(_ pack: Pack) -> Bool {
        !disabledPackIDs.contains(pack.id)
    }

    func setEnabled(_ isEnabled: Bool, for pack: Pack) {
        if isEnabled {
            disabledPackIDs.remove(pack.id)
        } else {
            disabledPackIDs.insert(pack.id)
        }
    }

    // MARK: - Persistence

    private static func defaultFileURL() -> URL? {
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return directory.appendingPathComponent("gin-settings.json")
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(SettingsSnapshot.self, from: data)
        else { return }

        isLoading = true
        level = snapshot.level
        disabledPackIDs = Set(snapshot.disabledPackIDs)
        dailyLimitMinutes = snapshot.dailyLimitMinutes
        pencilOnlyWriting = snapshot.pencilOnlyWriting
        isLoading = false
    }

    private func save() {
        guard !isLoading, let fileURL else { return }
        let snapshot = SettingsSnapshot(
            level: level,
            disabledPackIDs: Array(disabledPackIDs),
            dailyLimitMinutes: dailyLimitMinutes,
            pencilOnlyWriting: pencilOnlyWriting
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
