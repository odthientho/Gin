import SwiftUI

/// Motion and feedback.
///
/// The rule from the plan: feedback must land in under 100ms, on touch-*down*
/// rather than touch-up, and be exaggerated enough that a two-year-old connects
/// their finger to the result. A subtle animation reads as nothing happening.
enum Motion {

    /// The signature bounce. Overshoots deliberately — this is the "something
    /// happened!" feel, and a critically damped spring feels dead by comparison.
    static let pop = Animation.spring(response: 0.32, dampingFraction: 0.52)

    /// For things settling into place (a sticker landing, a card returning).
    static let settle = Animation.spring(response: 0.42, dampingFraction: 0.78)

    /// A wrong tap. The card shakes and the question repeats — it is never
    /// marked wrong, never removed, and never ends the round.
    static let wobble = Animation.easeInOut(duration: 0.09).repeatCount(4, autoreverses: true)

    /// Scale a tile jumps to while held.
    static let pressedScale: CGFloat = 1.12

    /// Scale a tile rests at when another one is being celebrated.
    static let recededScale: CGFloat = 0.96
}

/// The wrong-answer shake.
///
/// Note what this deliberately is *not*: red, an X, a buzzer, or a card that
/// disappears. A wrong tap in Gin means "not that one, listen again" and nothing
/// more. Drive `animatableData` from 0 to 1 to run it once.
struct Shake: GeometryEffect {
    var travelDistance: CGFloat = 16
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: travelDistance * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

/// Applies the press-and-pop feedback to any tappable surface.
///
/// Uses a `DragGesture` with zero distance rather than `onTapGesture` so the
/// visual response always fires on touch-down. `onTapGesture` waits for the
/// finger to lift, which is a ~200ms delay a toddler reads as the app being
/// broken.
///
/// **When the action fires is a separate question from when the tile pops.** A
/// control that stays on the same screen (an animal that speaks) acts on
/// touch-down — that is the responsiveness this app is built around.
///
/// A control that *navigates* acts on touch-up instead, which is how every iOS
/// control behaves: it lets a press be aborted by sliding a finger off, and that
/// escape hatch is worth having on a screen a toddler is mashing. The visual pop
/// still happens on touch-down either way, so nothing feels slower.
struct ToddlerTapFeedback: ViewModifier {
    let firesOnTouchDown: Bool
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far a finger may wander and still count as a tap rather than a drag.
    private let slop: CGFloat = 48

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? Motion.pressedScale : 1)
            .animation(Motion.pop, value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        if firesOnTouchDown { action() }
                    }
                    .onEnded { value in
                        isPressed = false
                        guard !firesOnTouchDown else { return }
                        // Generous slop: small hands slide while pressing, and
                        // that should still count as pressing.
                        let wandered = abs(value.translation.width) > slop
                            || abs(value.translation.height) > slop
                        if !wandered { action() }
                    }
            )
    }
}

extension View {
    /// Tap handling tuned for small hands: pops on touch-down and cannot be
    /// triggered twice by one clumsy press.
    ///
    /// Pass `firesOnTouchDown: false` for anything that changes screens.
    func toddlerTap(
        firesOnTouchDown: Bool = true,
        perform action: @escaping () -> Void
    ) -> some View {
        modifier(ToddlerTapFeedback(firesOnTouchDown: firesOnTouchDown, action: action))
    }
}
