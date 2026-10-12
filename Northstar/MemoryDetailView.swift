import SwiftUI

struct MemoryDetailView: View {

    let memory: Memory

    var body: some View {

        ZStack {

            Color(
                red: 0.08,
                green: 0.12,
                blue: 0.25
            )
            .ignoresSafeArea()

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 20
                ) {

                    HStack {

                        Label(
                            memory.category ?? "General",
                            systemImage: "brain.head.profile"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Text(
                            memory.createdAt.formatted(
                                date: .abbreviated,
                                time: .shortened
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    Text(memory.content)
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                }
                .padding(24)
            }
        }
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MemoryDetailView(
            memory: Memory(
                id: UUID(),
                identityId: UUID(),
                projectId: nil,
                content: "Example saved memory content.",
                category: "Reflection",
                createdAt: .now
            )
        )
    }
}
