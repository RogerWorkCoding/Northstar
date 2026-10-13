import SwiftUI

struct MemoryCardView: View {

    let memory: Memory

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 12
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
                        time: .omitted
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Text(memory.content)
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 6) {

                Image(
                    systemName: "sparkles"
                )

                Text("Saved Memory")
            }
            .font(.caption)
            .foregroundStyle(
                Color.yellow.opacity(0.85)
            )
        }
        .padding(18)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(
                Color.white.opacity(0.05)
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.08),
                lineWidth: 1
            )
        }
    }
}
