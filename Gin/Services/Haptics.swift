import UIKit

/// Physical feedback.
///
/// Toddlers respond to haptics more reliably than to sound — a buzz under the
/// finger is felt even when the iPad is muted or the room is loud. Generators are
/// prepared up front because an unprepared one has a noticeable warm-up delay,
/// which defeats the point.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let notice = UINotificationFeedbackGenerator()

    /// Call when a screen appears, so the first tap is as crisp as the tenth.
    static func prepare() {
        light.prepare()
        medium.prepare()
        notice.prepare()
    }

    /// Any tap on any tile.
    static func tap() {
        light.impactOccurred()
        light.prepare()
    }

    /// A correct answer, a completed count, a sticker earned.
    static func success() {
        notice.notificationOccurred(.success)
        notice.prepare()
    }

    /// A wrong tap. Deliberately *not* `.error` — an error buzz is a scolding,
    /// and nothing in Gin scolds. This is a soft nudge that says "not that one".
    static func nudge() {
        medium.impactOccurred(intensity: 0.6)
        medium.prepare()
    }

    /// A sticker snapping into place.
    static func snap() {
        medium.impactOccurred()
        medium.prepare()
    }
}
