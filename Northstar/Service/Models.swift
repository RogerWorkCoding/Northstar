import Foundation

struct AppIdentity: Codable, Identifiable {
    var id: UUID?
    var name: String
    var role: String?
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, role
        case createdAt = "created_at"
    }
}

struct AppProject: Codable, Identifiable {
    var id: UUID?
    var identityId: UUID
    var name: String
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case identityId = "identity_id"
        case createdAt = "created_at"
    }
}

struct AppDecision: Codable, Identifiable {
    var id: UUID?
    var projectId: UUID
    var topic: String
    var rule: String
    var status: String?
    var supersededBy: UUID?
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, topic, rule, status
        case projectId = "project_id"
        case supersededBy = "superseded_by"
        case createdAt = "created_at"
    }
}
struct Decision: Identifiable, Codable {
    var id: UUID?
    var projectId: String
    var topic: String
    var rule: String
    
    // This maps Swift's camelCase to Supabase's snake_case database columns
    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case topic
        case rule
    }
}
struct Project: Identifiable, Codable {
    var id: UUID?
    var identityId: String?
    var name: String
    var createdAt: String?
    
    // This maps Swift's camelCase to Supabase's snake_case database columns
    enum CodingKeys: String, CodingKey {
        case id
        case identityId = "identity_id"
        case name
        case createdAt = "created_at"
    }
}
