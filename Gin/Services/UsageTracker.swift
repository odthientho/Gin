import Foundation
import Observation

private struct UsageSnapshot: Codable {
    /// Start-of-day for the recorded usage, so a new day resets on its own.
    var day: Date = .distantPast
    var secondsUsed: Int = 0
}

/// Tracks how long the app has been open today, so the daily limit can end the
/// session gently instead of the parent having to.
///
/// Counts wall-clock time while the app is foregrounded. Deliberately crude — the
/// point is a soft stopping cue for a family, not billing accuracy.
@MainActor
@Observable
final class UsageTracker {

    private(set) var secondsUsedToday: Int = 0

    private let fileURL: URL?
    private var timer: Timer?
    private var day: Date = Calendar.current.startOfDay(for: .now)

    init(fileURL: URL? = UsageTracker.defaultFileURL()) {
        self.fileURL = fileURL
        load()
        rolloverIfNeeded()
    }

    /// Whether the child has reached the parent's limit. No limit set means never.
    func hasReachedLimit(_ limitMinutes: Int?) -> Bool {
        guard let limitMinutes else { return false }
        return secondsUsedToday >= limitMinutes * 60
    }

    func minutesRemaining(_ limitMinutes: Int?) -> Int? {
        guard let limitMinutes else { return nil }
        return max(0, limitMinutes - secondsUsedToday / 60)
    }

    // MARK: - Counting

    func startCounting() {
        rolloverIfNeeded()
        guard timer == nil else { return }

        // Ten-second granularity: fine for a soft limit, and 6x less writing to
        // disk than ticking every second.
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick(seconds: 10) }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopCounting() {
        timer?.invalidate()
        timer = nil
        save()
    }

    /// Used by the parent zone to hand back a fresh session.
    func resetToday() {
        secondsUsedToday = 0
        save()
    }

    private func tick(seconds: Int) {
        rolloverIfNeeded()
        secondsUsedToday += seconds
        save()
    }

    private func rolloverIfNeeded() {
        let today = Calendar.current.startOfDay(for: .now)
        guard today != day else { return }
        day = today
        secondsUsedToday = 0
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
        return directory.appendingPathComponent("gin-usage.json")
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data)
        else { return }
        day = snapshot.day
        secondsUsedToday = snapshot.secondsUsed
    }

    private func save() {
        guard let fileURL else { return }
        let snapshot = UsageSnapshot(day: day, secondsUsed: secondsUsedToday)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
