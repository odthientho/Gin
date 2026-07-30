import SwiftUI

/// Mechanic 08 — Add & Take Away.
///
/// The one genuinely new mechanic the arithmetic request needed, and the one
/// where most children's math apps go wrong by opening with a symbol. A child who
/// cannot yet hold "5" in their head as a *quantity* sees `3 + 2` as two shapes
/// and a cross.
///
/// So the objects come first and the symbol comes third:
///
/// - ``MathStep/objects`` — apples only. Tap each to count it, then pick the numeral.
/// - ``MathStep/bridge`` — the same apples, with the numerals written beneath.
/// - ``MathStep/symbols`` — `3 + 2 = ?` alone, with a hint tap that brings the apples back.
///
/// ## Taking away does not mean disappearing
///
/// The subtracted objects **stay on screen**, set aside behind a dashed fence,
/// blurred and impossible to tap. They are not removed and not faded out.
///
/// That matters: if three apples vanish, a child has to *remember* that five were
/// there to make sense of the question. Leaving them visible keeps the whole
/// story on screen at once — five altogether, three fenced off, two still countable
/// — which is the part-whole relationship subtraction actually is. The fence is
/// what makes them uncountable, so they cannot be counted back into the answer.
struct AddTakeAwayView: View {
    let pack: Pack
    let params: LevelParams
    let onRoundComplete: (Item) -> Void

    @Environment(AudioService.self) private var audio

    @State private var problem: MathProblem?
    @State private var countedIndices: Set<Int> = []
    /// Whether the subtracted objects have been fenced off yet.
    @State private var hasTakenAway = false
    @State private var chosenAnswer: Int?
    @State private var wrongAnswer: Int?
    @State private var shake: CGFloat = 0
    @State private var solved = 0
    @State private var isAdvancing = false
    @State private var showsObjectHint = false

    private var pool: [Item] { pack.items(for: params) }

    /// At the symbols step the objects are hidden until the child asks for them.
    private var showsObjects: Bool {
        params.mathStep != .symbols || showsObjectHint
    }

    var body: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            promptBar

            if let problem {
                stage(for: problem)
                answerRow(for: problem)
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
        .onAppear {
            Haptics.prepare()
            nextProblem()
        }
    }

    // MARK: - Prompt

    private var promptBar: some View {
        HStack(spacing: 18) {
            Button { speakPrompt() } label: {
                HStack(spacing: 20) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 36, weight: .semibold))
                    Text(promptText)
                        .font(Theme.TypeScale.prompt)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 40)
                .padding(.vertical, 22)
                .background(Theme.Palette.surface, in: Capsule())
                .shadow(color: Theme.Shadow.color, radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Repeat the question")

            // The escape hatch that makes the symbols step humane: a stuck child
            // gets the objects back rather than being stuck with abstraction.
            if params.mathStep == .symbols {
                Button {
                    withAnimation(Motion.settle) { showsObjectHint.toggle() }
                } label: {
                    Image(systemName: showsObjectHint ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(pack.color.color)
                        .frame(width: 88, height: 88)
                        .background(Theme.Palette.surface, in: Circle())
                        .shadow(color: Theme.Shadow.color, radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showsObjectHint ? "Hide the objects" : "Show the objects")
            }
        }
    }

    /// What is written on screen: always numerals, never number words. "5 − 3",
    /// not "5 − three". The digit is the thing being learned, so it is the thing
    /// that gets shown.
    private var promptText: String {
        guard let problem else { return " " }
        return "\(problem.left) \(problem.operation.symbol) \(problem.right) = ?"
    }

    /// What is said aloud, which is a different job. Speech synthesis needs words
    /// and a real sentence — "five take away three" — because a child is listening
    /// for language here, not reading an equation.
    private var spokenPrompt: String {
        guard let problem else { return "" }
        let noun = problem.item.name.lowercased()
        return switch problem.operation {
        case .add:
            "\(NumberWord.spoken(problem.left)) \(noun)s and \(NumberWord.spoken(problem.right)) more. How many?"
        case .subtract:
            "\(NumberWord.spoken(problem.left)) \(noun)s. Take away \(NumberWord.spoken(problem.right)). How many are left?"
        }
    }

    // MARK: - Stage

    private func stage(for problem: MathProblem) -> some View {
        VStack(spacing: 14) {
            if showsObjects {
                objectStage(for: problem)
            }
            if params.mathStep == .symbols {
                Text(promptText)
                    .font(.system(size: 84, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Palette.ink)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.surface.opacity(0.65),
                    in: RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner,
                                         style: .continuous))
    }

    @ViewBuilder
    private func objectStage(for problem: MathProblem) -> some View {
        switch problem.operation {
        case .add:
            HStack(spacing: 28) {
                group(for: problem, range: 0 ..< problem.left, label: problem.left)

                Text(problem.operation.symbol)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Palette.inkSoft)

                group(for: problem,
                      range: problem.left ..< (problem.left + problem.right),
                      label: problem.right)
            }
            .padding(24)

        case .subtract:
            VStack(spacing: 12) {
                HStack(spacing: 22) {
                    objectsRow(problem, range: 0 ..< (problem.left - problem.right))
                    takenAwayPen(for: problem)
                }
                // The minuend, labelling everything visible — the fenced-off ones
                // included, because they are still there. No operator symbol here:
                // it lives in the prompt, and putting one between the two clumps
                // would read as "2 − 3", which is not the sum being asked.
                if params.mathStep != .objects {
                    Text("\(problem.left)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(pack.color.color)
                }
            }
            .padding(24)
        }
    }

    /// The objects that were taken away: still on screen, fenced off, blurred, and
    /// deliberately impossible to tap so they cannot be counted into the answer.
    private func takenAwayPen(for problem: MathProblem) -> some View {
        objectsRow(problem, range: (problem.left - problem.right) ..< problem.left)
            .blur(radius: hasTakenAway ? 5 : 0)
            .opacity(hasTakenAway ? 0.5 : 1)
            .saturation(hasTakenAway ? 0.25 : 1)
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(
                        Theme.Palette.inkSoft.opacity(hasTakenAway ? 0.4 : 0),
                        style: StrokeStyle(lineWidth: 3, dash: [10, 8])
                    )
            }
            .overlay(alignment: .bottom) {
                if hasTakenAway, params.mathStep != .objects {
                    Text("\(problem.right)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .offset(y: 26)
                }
            }
            // Untappable, always. This is what stops a child counting the
            // taken-away objects back into their answer.
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.55), value: hasTakenAway)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(problem.right) \(problem.item.name.lowercased())s taken away")
    }

    private func group(for problem: MathProblem, range: Range<Int>, label: Int) -> some View {
        VStack(spacing: 12) {
            objectsRow(problem, range: range)
            // The bridge step: numerals appear beneath the objects they describe,
            // so the digit is attached to a quantity the child can still see.
            if params.mathStep != .objects {
                Text("\(label)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(pack.color.color)
            }
        }
    }

    private func objectsRow(_ problem: MathProblem, range: Range<Int>) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(range), id: \.self) { index in
                object(problem: problem, index: index)
            }
        }
    }

    private func object(problem: MathProblem, index: Int) -> some View {
        let isCounted = countedIndices.contains(index)

        return ArtView(art: problem.item.art, size: 54)
            .frame(width: 78, height: 78)
            .background {
                Circle().fill(isCounted ? pack.color.color.opacity(0.2) : .clear)
            }
            .overlay(alignment: .topTrailing) {
                if isCounted {
                    Text("\(countedOrder(of: index))")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(pack.color.color, in: Circle())
                }
            }
            .toddlerTap { countObject(index, problem: problem) }
            .accessibilityLabel(problem.item.name)
    }

    private func countedOrder(of index: Int) -> Int {
        countedIndices.filter { $0 <= index }.count
    }

    // MARK: - Answers

    private func answerRow(for problem: MathProblem) -> some View {
        HStack(spacing: Theme.Metrics.minGap) {
            ForEach(problem.choices, id: \.self) { value in
                numeralButton(value, problem: problem)
            }
        }
        .frame(height: 165)
    }

    private func numeralButton(_ value: Int, problem: MathProblem) -> some View {
        let isCorrect = chosenAnswer == value

        return Text("\(value)")
            .font(.system(size: 76, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minWidth: Theme.Metrics.minTouchTarget,
                   minHeight: Theme.Metrics.minTouchTarget)
            .background {
                RoundedRectangle(cornerRadius: Theme.Metrics.tileCorner, style: .continuous)
                    .fill(pack.color.color)
            }
            .overlay(alignment: .topTrailing) {
                if isCorrect {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Theme.Palette.leaf, in: Circle())
                        .offset(x: 14, y: -14)
                }
            }
            .shadow(color: Theme.Shadow.color,
                    radius: isCorrect ? Theme.Shadow.radius * 1.6 : Theme.Shadow.radius,
                    y: Theme.Shadow.y)
            .scaleEffect(isCorrect ? 1.08 : 1)
            .modifier(Shake(animatableData: wrongAnswer == value ? shake : 0))
            .animation(Motion.pop, value: isCorrect)
            .toddlerTap { choose(value, problem: problem) }
            .accessibilityLabel("\(value)")
    }

    // MARK: - Flow

    private func nextProblem() {
        var generator = SystemRandomNumberGenerator()
        countedIndices = []
        hasTakenAway = false
        chosenAnswer = nil
        wrongAnswer = nil
        showsObjectHint = false
        isAdvancing = false

        problem = RoundBuilder.mathProblem(
            from: pool,
            step: params.mathStep,
            using: &generator
        )

        guard let problem else { return }

        speakPrompt()

        // Subtraction: the objects stay put and the fence closes around them. The
        // beat before it closes is what lets a child see all five together first.
        guard problem.operation == .subtract else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            hasTakenAway = true
            Haptics.tap()
        }
    }

    private func speakPrompt() {
        audio.say(spokenPrompt)
    }

    private func countObject(_ index: Int, problem: MathProblem) {
        // The fenced-off objects are already untappable, but a counting rule this
        // load-bearing should not rest on hit-testing alone.
        guard !isAdvancing,
              !countedIndices.contains(index),
              !isTakenAway(index, in: problem)
        else { return }

        countedIndices.insert(index)
        Haptics.tap()
        let running = countedIndices.count
        audio.say(NumberWord.spoken(running), clip: NumberWord.clipName(running))
    }

    private func isTakenAway(_ index: Int, in problem: MathProblem) -> Bool {
        problem.operation == .subtract && index >= problem.left - problem.right
    }

    private func choose(_ value: Int, problem: MathProblem) {
        guard !isAdvancing else { return }

        if value == problem.answer {
            isAdvancing = true
            Haptics.success()
            withAnimation(Motion.pop) { chosenAnswer = value }
            audio.say(NumberWord.spoken(value), clip: NumberWord.clipName(value))
            solved += 1

            Task {
                try? await Task.sleep(for: .milliseconds(1300))
                if solved >= RoundBuilder.mathProblemsPerRound {
                    solved = 0
                    onRoundComplete(problem.item)
                } else {
                    nextProblem()
                }
            }
        } else {
            Haptics.nudge()
            wrongAnswer = value
            shake = 0
            withAnimation(.easeInOut(duration: 0.4)) { shake = 1 }
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                speakPrompt()
                wrongAnswer = nil
            }
        }
    }
}
