import Foundation
import AVFoundation

enum NorthstarVoiceStyle: String, CaseIterable {

    case calm = "Calm"
    case friendly = "Friendly"
    case professional = "Professional"
    case mentor = "Mentor"

    var identifier: String? {

        switch self {

        case .calm:
            return AVSpeechSynthesisVoice(
                language: "en-US"
            )?.identifier

        case .friendly:
            return AVSpeechSynthesisVoice(
                language: "en-GB"
            )?.identifier

        case .professional:
            return AVSpeechSynthesisVoice(
                language: "en-US"
            )?.identifier

        case .mentor:
            return AVSpeechSynthesisVoice(
                language: "en-AU"
            )?.identifier
        }
    }
}

final class NorthstarVoice {

    static let shared = NorthstarVoice()

    private let synthesizer =
        AVSpeechSynthesizer()

    var selectedVoice:
        NorthstarVoiceStyle = .calm

    func speak(_ text: String) {

        let utterance =
            AVSpeechUtterance(string: text)

        if let identifier =
            selectedVoice.identifier {

            utterance.voice =
                AVSpeechSynthesisVoice(
                    identifier: identifier
                )
        }

        utterance.rate = 0.48

        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(
            at: .immediate
        )
    }
}
