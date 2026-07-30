import SwiftUI

/// The shapes Gin draws rather than ships as images.
///
/// Shapes, colors, numerals and most flags are geometry, and geometry is cheaper,
/// sharper and more consistent in code than as ~40 image files. It also means a
/// shape is *data*: adding a hexagon is one case here, not an art commission.

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

struct Star: Shape {
    var points: Int = 5
    /// How deep the inner vertices sit, as a fraction of the outer radius.
    var innerRatio: CGFloat = 0.42

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        // Start at the top rather than at 0 radians, so the star points up.
        let start = -CGFloat.pi / 2

        var path = Path()
        for index in 0 ..< (points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = start + CGFloat(index) * .pi / CGFloat(points)
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

struct Heart: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        var path = Path()

        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + height * 0.28),
            control1: CGPoint(x: rect.midX - width * 0.32, y: rect.maxY - height * 0.22),
            control2: CGPoint(x: rect.minX, y: rect.midY)
        )
        path.addArc(
            center: CGPoint(x: rect.minX + width * 0.25, y: rect.minY + height * 0.28),
            radius: width * 0.25,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: rect.minX + width * 0.75, y: rect.minY + height * 0.28),
            radius: width * 0.25,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.midY),
            control2: CGPoint(x: rect.midX + width * 0.32, y: rect.maxY - height * 0.22)
        )
        path.closeSubpath()
        return path
    }
}

/// A Nordic-style off-centre cross, used by several flags.
struct FlagCross: Shape {
    var thickness: CGFloat = 0.22
    /// Fraction across the width where the vertical bar sits.
    var verticalOffset: CGFloat = 0.36

    func path(in rect: CGRect) -> Path {
        let barWidth = rect.width * thickness
        let barHeight = rect.height * thickness
        var path = Path()
        path.addRect(CGRect(
            x: rect.minX, y: rect.midY - barHeight / 2,
            width: rect.width, height: barHeight
        ))
        path.addRect(CGRect(
            x: rect.minX + rect.width * verticalOffset - barWidth / 2, y: rect.minY,
            width: barWidth, height: rect.height
        ))
        return path
    }
}
