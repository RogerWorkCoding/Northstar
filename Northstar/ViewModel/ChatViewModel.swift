import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {

    var messages: [MessageModel] = []
    var currentInput = ""
    var isLoading = false
}
