import SwiftUI

/// Draws the half of Gin's content that is geometry rather than illustration.
///
/// The `value` on a geometry ``Art`` is a small string grammar so a pack can add
/// content without any Swift change:
///
/// - `circle`, `square`, `triangle`, `star`, `heart`, `diamond` — a filled shape
/// - `swatch:#RRGGBB` — a color chip, with the color itself living in the pack
/// - `numeral:7` — a digit
/// - `letter:A` — a glyph, sized a little smaller than a numeral so that wide
///   capitals like W and M do not crowd their tile
///
/// Anything unrecognized renders as a visible placeholder rather than a blank
/// space, so a typo in a pack file is obvious the first time it is opened.
struct GeometryArtView: View {
    let value: String
    var size: CGFloat = 92
    /// Used for shapes and numerals, which take their color from the tile.
    var tint: Color = .white

    private static let shapeNames = ["circle", "square", "triangle", "star", "heart", "diamond"]

    private enum Kind {
        case shape(AnyShape)
        case swatch(Color)
        case numeral(String)
        case letter(String)
        case unknown
    }

    var body: some View {
        switch kind {
        case .shape(let shape):
            shape
                .fill(tint)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.18), radius: 4, y: 3)

        case .swatch(let color):
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 6))
                .shadow(color: .black.opacity(0.22), radius: 6, y: 4)

        case .numeral(let digits):
            Text(digits)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(0.18), radius: 3, y: 2)

        case .letter(let glyph):
            Text(glyph)
                .font(.system(size: size * 0.86, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(0.18), radius: 3, y: 2)

        case .unknown:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                .frame(width: size, height: size)
                .overlay {
                    Text(value)
                        .font(.caption)
                        .minimumScaleFactor(0.4)
                        .padding(4)
                }
                .foregroundStyle(tint.opacity(0.75))
        }
    }

    private var kind: Kind {
        if let hex = value.strippingPrefix("swatch:") {
            return .swatch(Color(hexString: hex) ?? .gray)
        }
        if let digits = value.strippingPrefix("numeral:") {
            return .numeral(digits)
        }
        if let glyph = value.strippingPrefix("letter:") {
            return .letter(glyph)
        }
        guard Self.shapeNames.contains(value) else { return .unknown }
        return .shape(Self.shape(named: value))
    }

    private static func shape(named name: String) -> AnyShape {
        switch name {
        case "square":   AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        case "triangle": AnyShape(Triangle())
        case "star":     AnyShape(Star())
        case "heart":    AnyShape(Heart())
        case "diamond":  AnyShape(Diamond())
        default:         AnyShape(Circle())
        }
    }
}

// MARK: - Helpers

extension String {
    func strippingPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}

extension Color {
    /// Parses `#RRGGBB`, which is how a pack file names a color.
    init?(hexString: String) {
        var cleaned = hexString.trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        self.init(hex: value)
    }
}
