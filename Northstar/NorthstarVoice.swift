import Foundation
import AVFoundation
import Observation

// 🔊 Northstar's voice: reads replies aloud with the iPhone's own voices (free, private, works offline).
// Settings → Voice: read replies aloud (on/off), which voice, and how fast.
// The voice only changes the sound; it's always the same Northstar.

/// The voices to choose from. Each uses the best voice of that accent on the phone
/// (Premium, then Enhanced, then the standard one).
nonisolated enum NorthstarVoiceChoice: String, CaseIterable, Identifiable, Sendable {
    case calmUS, warmUK, brightAU

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calmUS: return "Calm (US)"
        case .warmUK: return "Warm (UK)"
        case .brightAU: return "Bright (Australia)"
        }
    }

    var language: String {
        switch self {
        case .calmUS: return "en-US"
        case .warmUK: return "en-GB"
        case .brightAU: return "en-AU"
        }
    }

    /// The best installed voice for this accent.
    var voice: AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        func rank(_ q: AVSpeechSynthesisVoiceQuality) -> Int {
            switch q {
            case .premium: return 3
            case .enhanced: return 2
            default: return 1
            }
        }
        // Skip novelty voices (Apple marks some with names like "Bells"); keep the clearest one.
        let best = voices
            .filter { !$0.voiceTraits.contains(.isNoveltyVoice) }
            .max { rank($0.quality) < rank($1.quality) }
        return best ?? AVSpeechSynthesisVoice(language: language)
    }

    /// "Premium" / "Enhanced" / "" for the label in Settings.
    var qualityNote: String {
        switch voice?.quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default: return ""
        }
    }
}

nonisolated enum NorthstarVoiceSpeed: String, CaseIterable, Identifiable, Sendable {
    case slower, normal, faster
    var id: String { rawValue }
    var label: String {
        switch self {
        case .slower: return "Slower"
        case .normal: return "Normal"
        case .faster: return "Faster"
        }
    }
    var rate: Float {
        switch self {
        case .slower: return 0.42
        case .normal: return 0.5
        case .faster: return 0.56
        }
    }
}

@MainActor
@Observable
final class NorthstarVoice: NSObject, AVSpeechSynthesizerDelegate {

    static let shared = NorthstarVoice()

    /// The text being read right now (so a reply's speaker button can show "stop").
    private(set) var speakingText: String?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Read replies aloud automatically? (Settings → Voice)
    static var autoSpeak: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.speakReplies)
    }

    static var choice: NorthstarVoiceChoice {
        NorthstarVoiceChoice(rawValue: UserDefaults.standard.string(forKey: SettingsKeys.voice) ?? "") ?? .calmUS
    }

    static var speed: NorthstarVoiceSpeed {
        NorthstarVoiceSpeed(rawValue: UserDefaults.standard.string(forKey: SettingsKeys.voiceSpeed) ?? "") ?? .normal
    }

    /// Reads the text aloud (stops anything already playing first).
    func speak(_ text: String, voice: NorthstarVoiceChoice? = nil) {
        let spoken = Self.speakable(text)
        guard !spoken.isEmpty else { return }
        stop()

        // Plays even when the ring/silent switch is on silent, and lowers music while speaking.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: spoken)
        utterance.voice = (voice ?? Self.choice).voice
        utterance.rate = Self.speed.rate
        utterance.postUtteranceDelay = 0.1
        speakingText = text
        synthesizer.speak(utterance)
    }

    /// A short sample for the voice picker.
    func sample(_ voice: NorthstarVoiceChoice) {
        speak("Hi, I'm Northstar. Let's find your next step together.", voice: voice)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        speakingText = nil
    }

    func isSpeaking(_ text: String) -> Bool { speakingText == text }

    // MARK: AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }

    private func finished() {
        guard !synthesizer.isSpeaking else { return }
        speakingText = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The words only: no markdown stars, link addresses, bullets or emoji, so it sounds natural.
    nonisolated static func speakable(_ text: String) -> String {
        var s = text
        // [**Name**](https://…) → Name
        s = s.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        // Bare links
        s = s.replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
        // Bold, italics, headings, code ticks
        s = s.replacingOccurrences(of: #"[*_`#]+"#, with: "", options: .regularExpression)
        // Bullets at the start of a line → a pause
        s = s.replacingOccurrences(of: #"(?m)^\s*[•\-–]\s+"#, with: "", options: .regularExpression)
        // Dashes between parts of a line read as a short pause
        s = s.replacingOccurrences(of: " — ", with: ", ")
        // Emoji and symbols
        s = String(s.unicodeScalars.filter { !($0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x2000)) })
        // Line breaks become sentence breaks
        s = s.replacingOccurrences(of: #"\n+"#, with: ". ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\.\s*\."#, with: ".", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
