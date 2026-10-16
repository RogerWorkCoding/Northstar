import Foundation

struct MessageModel: Identifiable, Hashable, Sendable {

    enum Role: String, Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    /// Stage, what Northstar heard and save suggestions (assistant replies only).
    let insight: NorthstarInsight?
    /// A photo the person attached (small JPEG), shown in their bubble and sent with this message.
    let image: Data?

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = .now,
        insight: NorthstarInsight? = nil,
        image: Data? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.insight = insight
        self.image = image
    }
}
