import SwiftUI

struct MemorySearchView: View {

    @State private var searchText = ""
    @State private var memories: [Memory] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let memoryService = MemoryService()

    private let identityId = UUID(
        uuidString: "25bfa23f-efa6-45ff-ad16-1a2658e10d74"
    )!

    private var filteredMemories: [Memory] {

        guard !searchText.isEmpty else {
            return memories
        }

        return memories.filter { memory in

            memory.content
                .localizedCaseInsensitiveContains(
                    searchText
                )

            ||

            (memory.category ?? "")
                .localizedCaseInsensitiveContains(
                    searchText
                )
        }
    }

    var body: some View {

        ZStack {

            Color(
                red: 0.08,
                green: 0.12,
                blue: 0.25
            )
            .ignoresSafeArea()

            Group {

                if isLoading {

                    ProgressView(
                        "Loading Memory..."
                    )
                    .tint(.white)

                } else if let errorMessage {

                    Text(errorMessage)
                        .foregroundStyle(.white)

                } else if filteredMemories.isEmpty {

                    emptyState

                } else {

                    memoryList
                }
            }
        }
        .navigationTitle(
            "Search Memory"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .searchable(
            text: $searchText,
            prompt: "Search Memory"
        )
        .task {
            await loadMemories()
        }
    }

    private var memoryList: some View {

        List {

            ForEach(filteredMemories) { memory in

                NavigationLink {
                    MemoryDetailView(memory: memory)
                } label: {
                    MemoryCardView(
                        memory: memory
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)
                .listRowBackground(
                    Color.clear
                )
                .listRowSeparator(
                    .hidden
                )
                .swipeActions(
                    edge: .trailing
                ) {

                    Button(
                        role: .destructive
                    ) {

                        Task {
                            await delete(
                                memory
                            )
                        }

                    } label: {

                        Label(
                            "Delete",
                            systemImage: "trash"
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {

        VStack(spacing: 16) {

            Image(
                systemName:
                    "brain.head.profile"
            )
            .font(
                .system(size: 44)
            )
            .foregroundStyle(
                .white.opacity(0.7)
            )

            Text("No Memories Found")
                .foregroundStyle(.white)

            Text(
                "Saved memories will appear here."
            )
            .foregroundStyle(
                .white.opacity(0.6)
            )
        }
    }

    @MainActor
    private func loadMemories() async {

        isLoading = true

        do {

            memories =
                try await memoryService
                    .loadMemories(
                        identityId:
                            identityId
                    )

        } catch {

            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func delete(
        _ memory: Memory
    ) async {

        do {

            try await memoryService
                .deleteMemory(
                    id: memory.id
                )

            memories.removeAll {
                $0.id == memory.id
            }

        } catch {

            print(
                "Delete failed:",
                error
            )
        }
    }
}

#Preview {
    NavigationStack {
        MemorySearchView()
    }
}
