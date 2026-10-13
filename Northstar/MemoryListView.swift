import SwiftUI

struct MemoryListView: View {

    @State private var memories: [Memory] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let memoryService = MemoryService()

    private var identityId: UUID {
        SupabaseManager.shared.identityId
    }

    var body: some View {

        NavigationStack {

            Group {

                if isLoading {

                    ProgressView("Loading Memories...")

                } else if let errorMessage {

                    VStack(spacing: 16) {

                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)

                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                    }

                } else if memories.isEmpty {

                    ContentUnavailableView(
                        "No Memories",
                        systemImage: "brain",
                        description: Text(
                            "No memories have been saved yet."
                        )
                    )

                } else {

                    List(memories) { memory in

                        VStack(
                            alignment: .leading,
                            spacing: 8
                        ) {

                            Text(
                                memory.category ?? "General"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Text(memory.content)
                                .font(.body)

                            Text(
                                memory.createdAt.formatted(
                                    date: .abbreviated,
                                    time: .shortened
                                )
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Memory List")
            .task {
                await loadMemories()
            }
        }
    }

    private func loadMemories() async {

        isLoading = true

        do {

            memories = try await memoryService.loadMemories(
                identityId: identityId
            )

        } catch {

            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    MemoryListView()
}
