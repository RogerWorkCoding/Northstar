import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client = SupabaseClient(
        supabaseURL: URL(string: "https://ozvwmxgvlibaxkogjbpe.supabase.co")!,
        supabaseKey: "sb_publishable_5TLjbssyYV_kl6g9T7TudA_FCjZQFcf"
    )
    
    private init() {}

    // MARK: - Who is using the app

    /// The signed-in person's ID, or nil before sign-in finishes.
    var currentUserId: UUID? {
        client.auth.currentUser?.id
    }

    /// The person's identity ID. Each person's identity row uses their
    /// sign-in ID, so the lock rules in Supabase can match them.
    /// Before sign-in this is an empty ID that matches nothing.
    var identityId: UUID {
        currentUserId ?? UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))
    }

    /// Quietly signs the person in (no password screen yet) and makes sure
    /// they have an identity row. Safe to call every time the app opens.
    func signInIfNeeded() async {
        do {
            let userId: UUID
            if let existing = currentUserId {
                userId = existing
            } else {
                let session = try await client.auth.signInAnonymously()
                userId = session.user.id
            }

            struct IdentityRow: Encodable {
                let id: UUID
                let name: String
            }

            try await client
                .from("identities")
                .upsert(IdentityRow(id: userId, name: "Me"), ignoreDuplicates: true)
                .execute()

            print("✅ Signed in to Northstar.")
        } catch {
            print("❌ Sign-in failed:", error.localizedDescription)
        }
    }
    
    func testConnection() async {
        let testIdentity = AppIdentity(
            name: "Initial Architect",
            role: "Owner"
        )
        
        do {
            try await client
                .from("identities")
                .insert(testIdentity)
                .execute()
            
            print("🚀 Successfully wrote record to Supabase!")
        } catch {
            print("❌ Supabase connection error: \(error.localizedDescription)")
        }
    }
    
    func fetchDecisions() async throws -> [Decision] {
        let fetchedDecisions: [Decision] = try await client
            .from("decisions")
            .select()
            .execute()
            .value
            
        print("✅ Successfully downloaded \(fetchedDecisions.count) decisions.")
        return fetchedDecisions
    }
    
    func saveDecision(projectId: String, topic: String, rule: String) async throws {
        let newDecision = Decision(
            projectId: projectId,
            topic: topic,
            rule: rule
        )
        
        try await client
            .from("decisions")
            .insert(newDecision)
            .execute()
            
        print("✅ Successfully saved new rule to Supabase: \(topic)")
    }
    
    func fetchProjects() async throws -> [Project] {
        let fetchedProjects: [Project] = try await client
            .from("projects")
            .select()
            .execute()
            .value
            
        print("✅ Successfully downloaded \(fetchedProjects.count) projects.")
        return fetchedProjects
    }
    
    func saveProject(identityId: String, name: String) async throws {
        let newProject = Project(
            identityId: identityId,
            name: name
        )
        
        try await client
            .from("projects")
            .insert(newProject)
            .execute()
            
        print("✅ Successfully saved new project: \(name)")
    }
}
