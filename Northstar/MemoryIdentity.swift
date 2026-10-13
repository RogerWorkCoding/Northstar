import Foundation

struct MemoryIdentity: Codable, Identifiable {
    let id: UUID
    let name: String
    let role: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case createdAt = "created_at"
    }
}
