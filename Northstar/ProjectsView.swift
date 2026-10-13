import SwiftUI

struct ProjectsView: View {
    // Changed AppProject to Project to match our blueprint
    @State private var projects: [Project] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            // Background to match your dark theme
            Color(red: 0.05, green: 0.06, blue: 0.12)
                .ignoresSafeArea()
            
            VStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if projects.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No projects yet.")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                } else {
                    List(projects) { project in
                        HStack {
                            Text(project.name)
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            // This now actively pulls your data from Supabase
            do {
                projects = try await SupabaseManager.shared.fetchProjects()
                isLoading = false
            } catch {
                print("Failed to fetch: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }
}

#Preview {
    ProjectsView()
}
