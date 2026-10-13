import SwiftUI

struct MemoryApprovalView: View {

    @Environment(\.dismiss)
    private var dismiss

    let candidate: MemoryCandidate
    let onSave: (MemoryCandidate) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(
                    red: 0.08,
                    green: 0.12,
                    blue: 0.25
                )
                .ignoresSafeArea()

                VStack(
                    alignment: .leading,
                    spacing: 22
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        Label(
                            "Possible Memory",
                            systemImage: "sparkles"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            Color(
                                red: 0.84,
                                green: 0.70,
                                blue: 0.36
                            )
                        )

                        Text(
                            "Would you like Northstar to remember this?"
                        )
                        .font(
                            .system(
                                size: 26,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {
                        Text(
                            candidate.suggestedSubject
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .white.opacity(0.6)
                        )

                        Text(candidate.content)
                            .font(.body)
                            .foregroundStyle(.white)

                        Text(candidate.reason)
                            .font(.caption)
                            .foregroundStyle(
                                .white.opacity(0.55)
                            )
                    }
                    .padding(20)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background {
                        RoundedRectangle(
                            cornerRadius: 22,
                            style: .continuous
                        )
                        .fill(
                            .white.opacity(0.06)
                        )
                    }
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 22,
                            style: .continuous
                        )
                        .stroke(
                            .white.opacity(0.10),
                            lineWidth: 1
                        )
                    }

                    Spacer()

                    Button {
                        onSave(candidate)
                        dismiss()
                    } label: {
                        Label(
                            "Save to Memory",
                            systemImage: "brain.head.profile"
                        )
                        .font(.headline)
                        .foregroundStyle(
                            Color(
                                red: 0.08,
                                green: 0.12,
                                blue: 0.25
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background {
                            RoundedRectangle(
                                cornerRadius: 15,
                                style: .continuous
                            )
                            .fill(
                                Color(
                                    red: 0.84,
                                    green: 0.70,
                                    blue: 0.36
                                )
                            )
                        }
                    }

                    Button("Not Now") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(
                        .white.opacity(0.75)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .padding(24)
            }
            .navigationTitle("Northstar Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MemoryApprovalView(
        candidate: MemoryCandidate(
            content:
                "Northstar memory should be organized by subjects rather than keywords.",
            suggestedSubject:
                "Memory",
            reason:
                "This appears to define an ongoing project direction."
        ),
        onSave: { _ in }
    )
}
