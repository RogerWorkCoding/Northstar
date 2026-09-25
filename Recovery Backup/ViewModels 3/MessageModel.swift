import Foundation

struct MessageModel: Identifiable, Hashable {
    enum Role: String {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = .now
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
