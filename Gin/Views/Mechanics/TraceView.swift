import PencilKit
import SwiftUI

/// Mechanic 10 — Trace.
///
/// A dashed glyph with a green dot where the pen starts. The child writes over it
/// with the Apple Pencil; when they have followed the whole shape it fills in
/// solid, the letter is spoken back, and they move on.
///
/// ## What this deliberately is not
///
/// It is not handwriting *assessment*. There is no neatness score, no "try again",
/// and no way to fail — a glyph that has not been followed yet simply stays open.
/// The child decides when to move on with the arrow, not the app.
///
/// ## A note on age
///
/// Letter formation is a four-to-six-year-old skill. At two or three the real
/// prerequisites are the pre-writing strokes this pack opens with — a vertical
/// line, a horizontal line, a circle, a cross. Those come first in the pack for
/// exactly that reason, and they are genuinely where a toddler should start.
struct TraceView: View {
    let pack: Pack
    let params: LevelParams
    let onRoundComplete: (Item) -> Void

    @Environment(AudioService.self) private var audio
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var settings

    @State private var drawing = PKDrawing()
    @State private var assessment = TraceAssessment(coveredStrokes: [], coverage: 0, precision: 0)
    @State private var hasCelebrated = false
    @State private var completedThisRound = 0

    private static let glyphsPerRound = 3
    private let evaluator = TraceEvaluator()

    /// Only the traceable items, in authored order: pre-strokes, letters, digits.
    private var glyphs: [Item] { pack.items.filter { $0.trace != nil } }

    private var index: Int { min(progress.writingIndex, max(0, glyphs.count - 1)) }
    private var item: Item? { glyphs.indices.contains(index) ? glyphs[index] : nil }
    private var trace: GlyphTrace? { item?.trace }

    var body: some View {
        VStack(spacing: 18) {
            promptBar
            canvasArea
            controls
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
        .onAppear {
            Haptics.prepare()
            speakGlyph()
        }
    }

    // MARK: - Prompt

    private var promptBar: some View {
        Button { speakGlyph() } label: {
            HStack(spacing: 20) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 32, weight: .semibold))
                Text(item.map { "Trace the \($0.name)" } ?? " ")
                    .font(Theme.TypeScale.prompt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(Theme.Palette.ink)
            .padding(.horizontal, 40)
            .padding(.vertical, 18)
            .background(Theme.Palette.surface, in: Capsule())
            .shadow(color: Theme.Shadow.color, radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hear it again")
    }

    // MARK: - Canvas

    private var canvasArea: some View {
        GeometryReader { geometry in
            // Square, so a glyph's proportions never depend on the screen.
            let side = min(geometry.size.width, geometry.size.height)
            let size = CGSize(width: side, height: side)

            ZStack {
                RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .shadow(color: Theme.Shadow.color, radius: 14, y: 6)

                if let trace {
                    guideLayer(trace, size: size)
                    startDots(trace, size: size)
                }

                TraceCanvas(
                    drawing: $drawing,
                    inkColor: UIColor(pack.color.color),
                    pencilOnly: settings.pencilOnlyWriting
                )
                .frame(width: side, height: side)
                .onChange(of: drawing) { _, _ in
                    evaluate(in: size)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The dashed guide. A stroke the child has followed switches to solid, which
    /// is the only progress indicator the mechanic needs.
    private func guideLayer(_ trace: GlyphTrace, size: CGSize) -> some View {
        ZStack {
            ForEach(Array(trace.strokes(in: size).enumerated()), id: \.offset) { index, points in
                let isDone = assessment.coveredStrokes.contains(index)
                path(points)
                    .stroke(
                        pack.color.color.opacity(isDone ? 0.55 : 0.28),
                        style: StrokeStyle(
                            lineWidth: isDone ? 26 : 22,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: isDone ? [] : [16, 18]
                        )
                    )
                    .animation(Motion.settle, value: isDone)
            }
        }
    }

    private func startDots(_ trace: GlyphTrace, size: CGSize) -> some View {
        ZStack {
            ForEach(Array(trace.strokes.enumerated()), id: \.offset) { index, stroke in
                if !assessment.coveredStrokes.contains(index), let start = stroke.start {
                    Circle()
                        .fill(Theme.Palette.leaf)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                        .position(x: start.x * size.width, y: start.y * size.height)
                }
            }
        }
    }

    private func path(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: Theme.Metrics.minGap) {
            circleButton("chevron.left", label: "Previous letter", isEnabled: index > 0) {
                move(by: -1)
            }
            circleButton("arrow.counterclockwise", label: "Start over", isEnabled: !drawing.strokes.isEmpty) {
                clear()
            }
            circleButton(
                "chevron.right",
                label: "Next letter",
                isEnabled: index < glyphs.count - 1,
                tint: pack.color.color
            ) {
                move(by: 1)
            }
        }
        .frame(height: 96)
    }

    private func circleButton(
        _ systemName: String,
        label: String,
        isEnabled: Bool,
        tint: Color = Theme.Palette.ink,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(isEnabled ? tint : Theme.Palette.inkSoft.opacity(0.35))
                .frame(width: 96, height: 96)
                .background(Theme.Palette.surface, in: Circle())
                .shadow(color: Theme.Shadow.color, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    // MARK: - Flow

    private func speakGlyph() {
        guard let item else { return }
        audio.say(item.name, clip: item.voiceClip)
    }

    private func evaluate(in size: CGSize) {
        guard let trace, let item, !hasCelebrated else { return }

        assessment = evaluator.assess(
            guide: trace,
            ink: drawing.normalizedStrokes(in: size)
        )

        guard assessment.isComplete else { return }

        hasCelebrated = true
        Haptics.success()
        audio.say("\(item.name). Nice writing!")
        completedThisRound += 1

        Task {
            try? await Task.sleep(for: .milliseconds(1600))
            if completedThisRound >= Self.glyphsPerRound {
                completedThisRound = 0
                onRoundComplete(item)
            }
            move(by: 1)
        }
    }

    private func clear() {
        drawing = PKDrawing()
        assessment = TraceAssessment(coveredStrokes: [], coverage: 0, precision: 0)
        hasCelebrated = false
    }

    private func move(by offset: Int) {
        let next = index + offset
        guard glyphs.indices.contains(next) else { return }
        progress.setWritingIndex(next)
        clear()
        speakGlyph()
    }
}
