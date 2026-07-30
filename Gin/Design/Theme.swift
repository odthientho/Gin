import SwiftUI

/// Design tokens for Gin.
///
/// These are not suggestions. The touch-target and spacing numbers come from
/// Nielsen Norman's research on young children (a 2cm x 2cm minimum button,
/// roughly double an adult target) and every interactive surface in the app is
/// expected to go through `Theme.Metrics` rather than hard-coding a size.
enum Theme {

    // MARK: - Palette

    /// Saturated hues on a warm ground. Deliberately few: the research is
    /// explicit that 2-4 year olds do better with fewer, brighter colors than
    /// with a full spectrum.
    ///
    /// ## Why there are seven colors and eleven categories
    ///
    /// The original rule was one unique hue per category — color is how a
    /// pre-reader recognizes a category before they can read its name. That rule
    /// is correct and it does not scale. There are not eleven hues a three-year-old
    /// can tell apart and name; pushing past about eight forces neighbours so close
    /// (teal beside sky, coral beside mango) that color stops carrying information
    /// and starts actively misleading.
    ///
    /// So above eight categories color becomes a **family** cue rather than an
    /// identity: at most two packs share a hue, they are always from related
    /// domains, and their icons are unmistakably different. The icon carries
    /// identity, the color carries grouping. `PackIdentityTests` enforces the
    /// two-per-hue ceiling.
    ///
    /// | Hue | Family |
    /// | --- | ------ |
    /// | mango | Animals |
    /// | berry | Colors, Feelings — expressive |
    /// | sky | Shapes, Patterns — visual structure |
    /// | grape | Numbers, Letters — symbols |
    /// | leaf | Math, Opposites — reasoning |
    /// | sun | Vehicles |
    /// | teal | Flags |
    enum Palette {
        static let mango = Color(hex: 0xFF7A2F)
        static let berry = Color(hex: 0xE23D68)
        static let sky   = Color(hex: 0x1B8FD1)
        static let grape = Color(hex: 0x7A4FD4)
        static let leaf  = Color(hex: 0x1FA96A)
        static let sun   = Color(hex: 0xFFB627)
        /// Flags. Far enough from `sky` in hue to stay distinguishable side by
        /// side on the home grid, which is where the two would collide.
        static let teal  = Color(hex: 0x0E8F94)
        /// Writing. Graphite rather than a hue, because handwriting is a motor
        /// skill rather than a recognition category — and because pencil.
        ///
        /// Named `graphite`, not `ink`: `Palette.ink` is already the primary
        /// text colour, and a second constant with that name makes every use
        /// of either one ambiguous.
        static let graphite = Color(hex: 0x46566B)

        /// Warm neutrals, biased toward the orange accent so they read as
        /// chosen rather than inherited.
        static let background = Color(hex: 0xFFF9F3)
        static let surface    = Color(hex: 0xFFFFFF)
        static let ink        = Color(hex: 0x2A1D16)
        static let inkSoft    = Color(hex: 0x6B564A)
        static let hairline   = Color(hex: 0xF0DFD0)
    }

    // MARK: - Metrics

    enum Metrics {
        /// Minimum size for anything a child taps. ~2cm on a 10.9" iPad.
        static let minTouchTarget: CGFloat = 120

        /// Minimum gap between two tappable things. A toddler rests a whole
        /// palm on the glass; adjacent targets get mis-hit without this.
        static let minGap: CGFloat = 32

        static let screenPadding: CGFloat = 40
        static let tileCorner: CGFloat = 36
        static let cardCorner: CGFloat = 44
        static let pillCorner: CGFloat = 999
    }

    // MARK: - Typography

    /// SF Pro Rounded throughout. Rounded terminals read as friendly, it is
    /// the iOS-native face for children's apps, and it costs nothing to license.
    ///
    /// Note that *all* text in Gin is for the adult in the room, not the child.
    /// It is never required to operate anything, which is why the floor is 28pt
    /// — it gets read across a room, not up close.
    enum TypeScale {
        static let display = Font.system(size: 56, weight: .heavy, design: .rounded)
        static let title   = Font.system(size: 40, weight: .bold, design: .rounded)
        static let prompt  = Font.system(size: 34, weight: .bold, design: .rounded)
        static let label   = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let numeral = Font.system(size: 72, weight: .heavy, design: .rounded)
    }

    // MARK: - Elevation

    enum Shadow {
        static let color = Color(hex: 0x2A1D16).opacity(0.18)
        static let radius: CGFloat = 18
        static let y: CGFloat = 10
    }
}

// MARK: - Pack colors

/// The color tokens a content pack may name in JSON. Keeping this a closed enum
/// means a typo in a pack file fails to decode instead of silently rendering grey.
enum PackColor: String, Codable, Sendable, CaseIterable {
    case mango, berry, sky, grape, leaf, sun, teal, ink

    var color: Color {
        switch self {
        case .mango: Theme.Palette.mango
        case .berry: Theme.Palette.berry
        case .sky:   Theme.Palette.sky
        case .grape: Theme.Palette.grape
        case .leaf:  Theme.Palette.leaf
        case .sun:   Theme.Palette.sun
        case .teal:  Theme.Palette.teal
        case .ink:   Theme.Palette.graphite
        }
    }
}

// MARK: - Helpers

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
