import SwiftUI

struct DecisionsView: View {
    @State private var decisions: [Decision] = []
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
                } else if decisions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No rules yet.")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                } else {
                    List(decisions) { decision in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(decision.topic)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(decision.rule)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Decisions")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            // Pulls your data from Supabase
            do {
                decisions = try await SupabaseManager.shared.fetchDecisions()
                isLoading = false
            } catch {
                print("Failed to fetch: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }
}

#Preview {
    DecisionsView()
}
