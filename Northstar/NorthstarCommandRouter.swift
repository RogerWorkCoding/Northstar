import Foundation

enum NorthstarCommand {
    case saveMemory
    case saveConversation
    case none
}

final class NorthstarCommandRouter {

    func route(_ text: String) -> NorthstarCommand {

        let command = text
            .lowercased()
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        switch command {

        case "northstar save to memory":
            return .saveMemory

        case "northstar save our conversation",
             "save our conversation",
             "save this conversation",
             "save this discussion":
            return .saveConversation

        default:
            return .none
        }
    }
}
