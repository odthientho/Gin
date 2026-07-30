import PencilKit
import SwiftUI

/// The ink layer a child writes on.
///
/// Wraps `PKCanvasView` deliberately thinly. Notable choices:
///
/// - **No `PKToolPicker`.** A floating palette of pens, erasers and rulers is the
///   last thing a two-to-six-year-old needs. One fixed ink, chosen for them.
/// - **`drawingPolicy` is a setting.** `.pencilOnly` is the whole reason to use
///   PencilKit here: it gives palm rejection, so a child resting their whole hand
///   on the glass leaves no marks. The parent can switch to `.anyInput` when the
///   Pencil is flat or missing.
/// - **Scrolling off.** `PKCanvasView` is a `UIScrollView`; left alone it pans
///   and rubber-bands under a dragging finger, which would fight the tracing.
struct TraceCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let inkColor: UIColor
    let pencilOnly: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false

        canvas.isScrollEnabled = false
        canvas.bouncesZoom = false
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1

        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        canvas.tool = Self.tool(color: inkColor)
        canvas.drawing = drawing
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Guarding each assignment keeps SwiftUI from looping: the delegate writes
        // the binding, which re-runs this method, which would write the canvas.
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
        let policy: PKCanvasViewDrawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        if canvas.drawingPolicy != policy {
            canvas.drawingPolicy = policy
        }
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// Fat, opaque, low-pressure-sensitivity ink. A thin nib reads as a scratch;
    /// a child needs to see a bold mark appear under the tip.
    private static func tool(color: UIColor) -> PKInkingTool {
        PKInkingTool(.pen, color: color, width: 22)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: TraceCanvas

        init(_ parent: TraceCanvas) {
            self.parent = parent
            super.init()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

extension PKDrawing {
    /// The child's ink as normalized 0...1 strokes, ready for ``TraceEvaluator``.
    ///
    /// `interpolatedPoints` rather than the raw control points: PencilKit stores a
    /// smoothed spline, and sampling it at a fixed spacing gives an even
    /// distribution to measure against, which raw control points do not.
    func normalizedStrokes(in size: CGSize) -> [[CGPoint]] {
        guard size.width > 0, size.height > 0 else { return [] }
        return strokes.map { stroke in
            stroke.path.interpolatedPoints(by: .distance(6)).map { point in
                CGPoint(
                    x: point.location.x / size.width,
                    y: point.location.y / size.height
                )
            }
        }
    }
}
