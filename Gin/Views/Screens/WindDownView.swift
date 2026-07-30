import SwiftUI

/// The end of a session.
///
/// A gentle wind-down beats a hard cut by a wide margin — an app that vanishes
/// mid-activity produces exactly the meltdown the daily limit was meant to avoid.
/// So Gin goes to sleep, visibly and calmly, and the child gets a cue they can
/// understand rather than a door slamming.
///
/// There is deliberately no "five more minutes" button here. More time is granted
/// by a parent, behind the gate, which is what keeps this from becoming something
/// to negotiate with.
struct WindDownView: View {
    let onParentGate: () -> Void

    @Environment(AudioService.self) private var audio
    @State private var isBreathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.Palette.grape.opacity(0.35),
                    Theme.Palette.ink.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Text("🐣")
                    .font(.system(size: 170))
                    .scaleEffect(isBreathing && !reduceMotion ? 1.05 : 0.97)
                    .animation(
                        .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                        value: isBreathing
                    )

                Text("Gin is going to sleep")
                    .font(Theme.TypeScale.title)
                    .foregroundStyle(.white)

                Text("See you tomorrow")
                    .font(Theme.TypeScale.label)
                    .foregroundStyle(.white.opacity(0.75))
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: onParentGate) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 76, height: 76)
                            .background(.white.opacity(0.16), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Grown-ups")
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .onAppear {
            isBreathing = true
            audio.say("Gin is going to sleep. See you tomorrow.")
        }
    }
}
