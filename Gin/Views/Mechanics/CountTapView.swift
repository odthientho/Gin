import SwiftUI

/// Mechanic 05 — Count & Tap.
///
/// The child taps each object exactly once and hears the running count. This is
/// the mechanic that teaches **one-to-one correspondence** — the understanding
/// that counting means pairing one number word with one thing — which is the
/// actual foundation under everything the Math pack does later, and is far more
/// important at this age than knowing what "5" looks like.
///
/// An object that has already been counted stays visibly counted. A toddler who
/// loses their place should be able to see where they were, not start over.
struct CountTapView: View {
    let pack: Pack
    let params: LevelParams
    let onRoundComplete: (Item) -> Void

    @Environment(AudioService.self) private var audio

    @State private var task: CountingTask?
    @State private var countedIndices: Set<Int> = []
    @State private var completedTasks = 0
    @State private var isAdvancing = false

    private var pool: [Item] { pack.items(for: params) }

    var body: some View {
        VStack(spacing: Theme.Metrics.minGap) {
            promptBar

            if let task {
                objectGrid(for: task)
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
        .onAppear {
            audio.prewarm(pool.map(\.voiceClip))
            nextTask()
        }
    }

    // MARK: - Pieces

    private var promptBar: some View {
        Button {
            speakPrompt()
        } label: {
            HStack(spacing: 20) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 36, weight: .semibold))
                Text(promptText)
                    .font(Theme.TypeScale.prompt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let task, !countedIndices.isEmpty {
                    Text(NumberWord.spoken(countedIndices.count).capitalized)
                        .font(Theme.TypeScale.prompt)
                        .foregroundStyle(pack.color.color)
                        .contentTransition(.numericText())
                    let _ = task
                }
            }
            .foregroundStyle(Theme.Palette.ink)
            .padding(.horizontal, 44)
            .padding(.vertical, 22)
            .background(Theme.Palette.surface, in: Capsule())
            .shadow(color: Theme.Shadow.color, radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Repeat the question")
    }

    private var promptText: String {
        guard let task else { return " " }
        return "Count the \(task.item.name.lowercased())s"
    }

    private func objectGrid(for task: CountingTask) -> some View {
        let columns = task.quantity <= 5
            ? task.quantity
            : Int((Double(task.quantity) / 2).rounded(.up))

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Metrics.minGap),
                           count: max(1, columns)),
            spacing: Theme.Metrics.minGap
        ) {
            ForEach(0 ..< task.quantity, id: \.self) { index in
                countable(task: task, index: index)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func countable(task: CountingTask, index: Int) -> some View {
        let isCounted = countedIndices.contains(index)

        return ArtView(art: task.item.art, size: 96)
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .background {
                Circle()
                    .fill(isCounted ? pack.color.color.opacity(0.22) : Theme.Palette.surface)
                    .shadow(color: Theme.Shadow.color, radius: 10, y: 4)
            }
            .overlay(alignment: .topTrailing) {
                if isCounted {
                    Text(NumberWord.spoken(countedOrder(of: index)))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(pack.color.color, in: Circle())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isCounted ? 0.94 : 1)
            .animation(Motion.pop, value: isCounted)
            .toddlerTap { count(index, in: task) }
            .accessibilityLabel(isCounted ? "Counted" : task.item.name)
    }

    /// Which number this object was given when it was tapped.
    private func countedOrder(of index: Int) -> Int {
        countedIndices.filter { $0 <= index }.count
    }

    // MARK: - Flow

    private func nextTask() {
        var generator = SystemRandomNumberGenerator()
        countedIndices = []
        isAdvancing = false

        task = RoundBuilder.countingTask(
            from: pool,
            maxQuantity: params.maxCountingQuantity,
            avoiding: task?.item.id,
            using: &generator
        )
        speakPrompt()
    }

    private func speakPrompt() {
        audio.say(promptText)
    }

    private func count(_ index: Int, in task: CountingTask) {
        // Tapping the same object twice must not advance the count — that is the
        // exact misconception this mechanic exists to correct.
        guard !isAdvancing, !countedIndices.contains(index) else { return }

        countedIndices.insert(index)
        let runningTotal = countedIndices.count
        audio.say(NumberWord.spoken(runningTotal), clip: NumberWord.clipName(runningTotal))

        guard runningTotal == task.quantity else { return }

        isAdvancing = true
        completedTasks += 1

        Task {
            try? await Task.sleep(for: .milliseconds(800))
            audio.say("\(NumberWord.spoken(task.quantity)) \(task.item.name.lowercased())s")
            try? await Task.sleep(for: .milliseconds(1200))

            if completedTasks >= RoundBuilder.countingTasksPerRound {
                completedTasks = 0
                onRoundComplete(task.item)
            }
            // A sticker never ends play — there is always another thing to count.
            nextTask()
        }
    }
}
