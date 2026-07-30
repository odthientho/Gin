import AVFoundation
import Observation

/// Speech and sound effects.
///
/// Gin is an audio-first app: every prompt is spoken, no instruction is ever
/// written for the child, and a word is *always* said aloud rather than read.
/// That makes latency the thing that matters most here — a 300ms delay before
/// a tapped animal speaks reads as the app being broken, so players are warmed
/// up before the first tap rather than created on demand.
///
/// Phase 1 runs entirely on synthesized speech. The real recordings replace it
/// in Phase 6 with no call-site changes: ``speak(_:)`` looks for a bundled clip
/// first and only falls back to the synthesizer when one is missing.
@MainActor
@Observable
final class AudioService {

    /// Muted from the speaker button on the home screen. The child can toggle
    /// this themselves — it is the one setting that is not behind the gate,
    /// because a parent needs to silence the iPad in one tap.
    var isMuted = false

    private let synthesizer = AVSpeechSynthesizer()
    private var players: [String: AVAudioPlayer] = [:]

    init() {
        configureSession()
    }

    private func configureSession() {
        // `.playback` rather than `.ambient` deliberately: the entire app is
        // audio-first, so honoring the hardware mute switch would leave a child
        // with a silent app they cannot operate. The in-app speaker button is
        // the mute control instead.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio is a degradation, not a crash — the app stays usable silently.
            print("[Gin] Audio session unavailable: \(error.localizedDescription)")
        }
    }

    // MARK: - Warm-up

    /// Preloads the clips a screen is about to need. Call on appear, not on tap.
    func prewarm(_ clipNames: [String]) {
        for name in clipNames where players[name] == nil {
            guard let player = makePlayer(named: name) else { continue }
            player.prepareToPlay()
            players[name] = player
        }
    }

    // MARK: - Speaking

    /// Says a word. Uses the recorded clip when it exists, synthesized speech
    /// until it does.
    func speak(_ item: Item) {
        say(item.name, clip: item.voiceClip)
    }

    /// Says arbitrary text — a prompt, a counting number, a bit of praise.
    ///
    /// `clip` names a recorded file to prefer. Prompts like "Where is the cow?"
    /// will eventually be a recorded carrier phrase plus the item's own clip;
    /// until then they synthesize as one sentence.
    func say(_ text: String, clip: String? = nil) {
        guard !isMuted else { return }

        if let clip, let player = player(named: clip) {
            play(player)
        } else {
            synthesize(text)
        }
    }

    /// Plays a non-speech sound: a moo, an engine, a siren. Silently does
    /// nothing when the clip is not in the bundle yet.
    func playEffect(_ clipName: String?) {
        guard !isMuted, let clipName, let player = player(named: clipName) else { return }
        play(player)
    }

    /// Says a word, then its sound effect a beat later — the Discover pattern.
    func speakThenEffect(_ item: Item) {
        speak(item)
        guard let effect = item.effectClip, players[effect] != nil else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            playEffect(effect)
        }
    }

    /// Whether a recorded clip is actually in the bundle.
    ///
    /// Used to hide mechanics that are meaningless without real audio — Hear It
    /// is not a game if every "sound" is the synthesizer reading the animal's
    /// name, so the play button skips it until the recordings land.
    nonisolated func hasClip(_ name: String?) -> Bool {
        guard let name else { return false }
        return Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Audio") != nil
            || Bundle.main.url(forResource: name, withExtension: "m4a") != nil
    }

    // MARK: - Internals

    private func player(named name: String) -> AVAudioPlayer? {
        if let cached = players[name] { return cached }
        guard let player = makePlayer(named: name) else { return nil }
        players[name] = player
        return player
    }

    private func makePlayer(named name: String) -> AVAudioPlayer? {
        let url = Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Audio")
            ?? Bundle.main.url(forResource: name, withExtension: "m4a")
        guard let url else { return nil }
        return try? AVAudioPlayer(contentsOf: url)
    }

    private func play(_ player: AVAudioPlayer) {
        player.currentTime = 0
        player.play()
    }

    private func synthesize(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        // Slower than default. Toddlers need the word held long enough to copy.
        utterance.rate = 0.42
        utterance.pitchMultiplier = 1.1
        synthesizer.speak(utterance)
    }
}
