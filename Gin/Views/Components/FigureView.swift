import SwiftUI

/// Draws a ``LogicFigure``: its shape, repeated `count` times, in its colour at
/// its size.
///
/// Every dimension derives from the cell it is given, so a figure fits whatever
/// space the grid can spare — a 3×3 of three large stars has to sit in the same
/// screen as a single small circle.
struct FigureView: View {
    let figure: LogicFigure
    /// The side of the square cell this figure has to live inside.
    let cell: CGFloat

    var body: some View {
        HStack(spacing: glyph * 0.10) {
            ForEach(0 ..< figure.count, id: \.self) { _ in
                Self.shape(figure.shape)
                    .fill(figure.color.color)
                    .frame(width: glyph, height: glyph)
            }
        }
        .frame(width: cell, height: cell)
    }

    /// Sized so three large glyphs still fit the cell with room to breathe.
    private var glyph: CGFloat {
        let slot = cell * 0.88 / CGFloat(max(1, figure.count))
        return slot * 0.88 * figure.size.scale
    }

    static func shape(_ shape: LogicFigure.Shape) -> AnyShape {
        switch shape {
        case .circle:   AnyShape(Circle())
        case .square:   AnyShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .triangle: AnyShape(Triangle())
        case .star:     AnyShape(Star())
        case .diamond:  AnyShape(Diamond())
        case .heart:    AnyShape(Heart())
        }
    }
}
