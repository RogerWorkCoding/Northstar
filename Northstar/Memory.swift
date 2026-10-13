import Foundation

struct Memory: Codable, Identifiable {
    let id: UUID
    let identityId: UUID
    let projectId: UUID?
    let content: String
    let category: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case identityId = "identity_id"
        case projectId = "project_id"
        case content
        case category
        case createdAt = "created_at"
    }
}
