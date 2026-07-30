import SwiftUI

/// The parental gate.
///
/// Apple requires one before settings, external links or a review prompt, and
/// rejects gates a four-year-old could brute-force — so a single tap, a fixed PIN
/// or a "are you a grown-up?" button will not pass review.
///
/// This one spells a two-digit number **in words** and asks for the numeral, with
/// both the number and the decoy positions randomized every time. Reading a word
/// is the barrier: it is trivial for any adult and genuinely out of reach for a
/// pre-reader, which is exactly the line the guideline is drawing.
struct ParentGateView: View {
    let onPass: () -> Void
    let onCancel: () -> Void

    @State private var answer = Int.random(in: 11 ... 39)
    @State private var choices: [Int] = []
    @State private var wrongChoice: Int?
    @State private var shake: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.Palette.ink.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 32) {
                Text("Ask a grown-up")
                    .font(Theme.TypeScale.label)
                    .foregroundStyle(Theme.Palette.inkSoft)

                Text("Tap \(spelled(answer))")
                    .font(Theme.TypeScale.title)
                    .foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.center)

                HStack(spacing: 20) {
                    ForEach(choices, id: \.self) { value in
                        numberButton(value)
                    }
                }

                Button(action: onCancel) {
                    Text("Never mind")
                        .font(Theme.TypeScale.label)
                        .foregroundStyle(Theme.Palette.inkSoft)
                        .frame(minWidth: 240, minHeight: 88)
                        .background(Theme.Palette.background, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(52)
            .background(Theme.Palette.surface,
                        in: RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner,
                                             style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 40, y: 16)
            .padding(Theme.Metrics.screenPadding)
        }
        .onAppear(perform: newChallenge)
        .accessibilityAddTraits(.isModal)
    }

    private func numberButton(_ value: Int) -> some View {
        Button {
            choose(value)
        } label: {
            Text("\(value)")
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 132, height: 132)
                .background(Theme.Palette.sky,
                            in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(Shake(animatableData: wrongChoice == value ? shake : 0))
        .accessibilityLabel("\(value)")
    }

    // MARK: - Challenge

    private func newChallenge() {
        answer = Int.random(in: 11 ... 39)

        // Decoys share a digit with the answer often enough that skimming does
        // not work, which is the point.
        var options: Set<Int> = [answer]
        while options.count < 3 {
            options.insert(Int.random(in: 11 ... 39))
        }
        choices = options.shuffled()
        wrongChoice = nil
    }

    private func choose(_ value: Int) {
        guard value == answer else {
            Haptics.nudge()
            wrongChoice = value
            shake = 0
            withAnimation(.easeInOut(duration: 0.4)) { shake = 1 }
            // A fresh challenge after a miss, so repeated guessing gains nothing.
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(Motion.settle) { newChallenge() }
            }
            return
        }
        Haptics.success()
        onPass()
    }

    /// Numbers as words. Only 11...39 is ever needed, so this stays explicit
    /// rather than pulling in a formatter whose output could be localized
    /// out from under the puzzle.
    private func spelled(_ value: Int) -> String {
        let teens = [
            11: "eleven", 12: "twelve", 13: "thirteen", 14: "fourteen",
            15: "fifteen", 16: "sixteen", 17: "seventeen", 18: "eighteen",
            19: "nineteen"
        ]
        if let word = teens[value] { return word }

        let tens = [2: "twenty", 3: "thirty"]
        let tensDigit = value / 10
        let onesDigit = value % 10
        guard let tensWord = tens[tensDigit] else { return "\(value)" }
        guard onesDigit > 0 else { return tensWord }
        return "\(tensWord)-\(NumberWord.spoken(onesDigit))"
    }
}
