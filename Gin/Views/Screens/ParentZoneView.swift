import SwiftUI

/// Everything the parent controls, reachable only through ``ParentGateView``.
///
/// Styled as a plain, dense, adult iOS screen on purpose. It should look nothing
/// like the child's app — that visual break is what tells a parent they have left
/// the toy and are now in the settings, and it removes any temptation for a child
/// to treat this as another place to play.
struct ParentZoneView: View {
    let packs: [Pack]
    let onClose: () -> Void

    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progress
    @Environment(UsageTracker.self) private var usage

    @State private var isConfirmingReset = false

    var body: some View {
        NavigationStack {
            Form {
                levelSection
                packSection
                writingSection
                timeSection
                progressSection
                aboutSection
            }
            .navigationTitle("Grown-ups")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose).fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var levelSection: some View {
        Section {
            Picker("Level", selection: Binding(
                get: { settings.level },
                set: { settings.level = $0 }
            )) {
                ForEach(Level.allCases) { level in
                    Text("\(level.parentFacingName) · \(level.parentFacingAgeRange)")
                        .tag(level)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Level")
        } footer: {
            Text("""
            Levels do not swap the content out — a Big child still gets Animals, \
            just with more choices and a bigger pool. What changes is which packs \
            appear at all: Math and Flags are Big only.
            """)
        }
    }

    private var packSection: some View {
        Section {
            ForEach(packs) { pack in
                Toggle(isOn: Binding(
                    get: { settings.isEnabled(pack) },
                    set: { settings.setEnabled($0, for: pack) }
                )) {
                    HStack(spacing: 12) {
                        Text(pack.icon)
                        Text(pack.title)
                        if pack.minLevel > .little {
                            Text(pack.minLevel.parentFacingName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }
        } header: {
            Text("Categories")
        } footer: {
            Text("A switched-off category is absent from the home screen, not locked. There is nothing for a child to find and be frustrated by.")
        }
    }

    private var writingSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.pencilOnlyWriting },
                set: { settings.pencilOnlyWriting = $0 }
            )) {
                Text("Apple Pencil only")
            }
        } header: {
            Text("Writing")
        } footer: {
            Text("""
            On means a resting palm or stray finger leaves no marks, which is \
            what makes tracing workable for a small child. Turn it off if the \
            Pencil is flat and you want a finger to draw.
            """)
        }
    }

    private var timeSection: some View {
        Section {
            Picker("Daily limit", selection: Binding(
                get: { settings.dailyLimitMinutes },
                set: { settings.dailyLimitMinutes = $0 }
            )) {
                ForEach(SettingsStore.limitOptions, id: \.self) { option in
                    if let option {
                        Text("\(option) minutes").tag(option)
                    } else {
                        Text("No limit").tag(Int?.none)
                    }
                }
            }

            HStack {
                Text("Used today")
                Spacer()
                Text("\(usage.secondsUsedToday / 60) min")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Button("Give more time today") {
                usage.resetToday()
            }
            .disabled(usage.secondsUsedToday == 0)
        } header: {
            Text("Screen time")
        } footer: {
            Text("When the limit is reached, Gin says goodnight rather than cutting off mid-activity. Ending on a soft cue is far easier on everyone than a hard stop.")
        }
    }

    private var progressSection: some View {
        Section {
            HStack {
                Text("Stickers earned")
                Spacer()
                Text("\(progress.earnedStickerIDs.count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Button("Clear all stickers", role: .destructive) {
                isConfirmingReset = true
            }
            .disabled(progress.earnedStickerIDs.isEmpty)
            .confirmationDialog(
                "Clear every sticker?",
                isPresented: $isConfirmingReset,
                titleVisibility: .visible
            ) {
                Button("Clear all stickers", role: .destructive) {
                    progress.resetAll()
                }
                Button("Keep them", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        } header: {
            Text("Progress")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.shortVersion).foregroundStyle(.secondary)
            }
            HStack {
                Text("Ads and purchases")
                Spacer()
                Text("None").foregroundStyle(.secondary)
            }
            HStack {
                Text("Data collected")
                Spacer()
                Text("None").foregroundStyle(.secondary)
            }
            HStack {
                Text("Internet access")
                Spacer()
                Text("Never").foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        } footer: {
            Text("Gin has no analytics, no accounts, no third-party code and no network calls of any kind. Everything your child does stays on this iPad.")
        }
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
