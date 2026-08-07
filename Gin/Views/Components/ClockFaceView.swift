import SwiftUI

/// An analogue clock, drawn rather than shipped as art.
///
/// Every proportion derives from `size`, so the same face works as a big
/// question and as a small answer chip.
///
/// The two hands are deliberately *very* different — the hour hand is short and
/// fat, the minute hand long and thin. On a real watch they are near enough alike
/// that adults tell them apart by habit; a child cannot, and confusing them is
/// the single most common mistake in learning to read a dial.
struct ClockFaceView: View {
    let time: ClockTime
    let size: CGFloat
    var accent: Color = Theme.Palette.berry

    var body: some View {
        ZStack {
            dial
            hourTicks
            numerals
            hand(
                lengthFraction: 0.28,
                width: size * 0.055,
                angle: time.hourAngle,
                color: Theme.Palette.ink
            )
            hand(
                lengthFraction: 0.40,
                width: size * 0.028,
                angle: time.minuteAngle,
                color: accent
            )
            Circle()
                .fill(Theme.Palette.ink)
                .frame(width: size * 0.075, height: size * 0.075)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(time.spoken)
    }

    // MARK: - Face

    private var dial: some View {
        Circle()
            .fill(Theme.Palette.surface)
            .overlay(Circle().strokeBorder(Theme.Palette.ink.opacity(0.85), lineWidth: size * 0.035))
            .shadow(color: Theme.Shadow.color, radius: size * 0.04, y: size * 0.015)
    }

    private var hourTicks: some View {
        ForEach(0 ..< 12, id: \.self) { index in
            Capsule()
                .fill(Theme.Palette.ink.opacity(0.75))
                .frame(width: size * 0.022, height: size * 0.055)
                .offset(y: -size * 0.415)
                .rotationEffect(.degrees(Double(index) * 30))
        }
    }

    /// Placed by trigonometry rather than rotated into position, so every
    /// numeral stays upright instead of fanning around the rim.
    private var numerals: some View {
        ForEach(1 ... 12, id: \.self) { number in
            let angle = Double(number) * .pi / 6
            Text("\(number)")
                .font(.system(size: size * 0.115, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Palette.ink)
                .position(
                    x: size / 2 + size * 0.325 * sin(angle),
                    y: size / 2 - size * 0.325 * cos(angle)
                )
        }
        .frame(width: size, height: size)
    }

    private func hand(
        lengthFraction: CGFloat,
        width: CGFloat,
        angle: Double,
        color: Color
    ) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: size * lengthFraction)
            // Pivot about the centre of the face, not the middle of the hand.
            .offset(y: -size * lengthFraction / 2)
            .rotationEffect(.degrees(angle))
    }
}
