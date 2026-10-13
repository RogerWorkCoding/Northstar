import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client = SupabaseClient(
        supabaseURL: URL(string: "https://ozvwmxgvlibaxkogjbpe.supabase.co")!,
        supabaseKey: "sb_publishable_5TLjbssyYV_kl6g9T7TudA_FCjZQFcf"
    )
    
    private init() {}
    
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
