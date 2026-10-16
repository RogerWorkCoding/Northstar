import SwiftUI

struct LivePDFDraftView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Binding var documentText: String

    let isRecording: Bool
    let onMicrophoneTapped: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(
                    red: 0.08,
                    green: 0.12,
                    blue: 0.25
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    liveStatus

                    documentPage

                    controls
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
            .navigationTitle("PDF Draft")
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

    private var liveStatus: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(
                    isRecording
                    ? NorthstarChatStyle.listening
                    : Color.secondary
                )
                .frame(width: 8, height: 8)

            Text(
                isRecording
                ? "Listening..."
                : "Ready to dictate"
            )
            .font(.caption)
            .foregroundStyle(.white.opacity(0.75))

            Spacer()

            Text("\(documentText.count) characters")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 8)
    }

    private var documentPage: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(
                cornerRadius: 6,
                style: .continuous
            )
            .fill(Color.white)
            .shadow(
                color: .black.opacity(0.25),
                radius: 12,
                x: 0,
                y: 6
            )

            if documentText.isEmpty {
                Text(
                    "Tap the microphone and begin speaking, or type here."
                )
                .font(.system(size: 16))
                .foregroundStyle(.gray)
                .padding(28)
            }

            TextEditor(
                text: $documentText
            )
            .font(
                .system(
                    size: 17,
                    weight: .regular,
                    design: .default
                )
            )
            .foregroundStyle(
                Color(
                    red: 0.08,
                    green: 0.12,
                    blue: 0.25
                )
            )
            .scrollContentBackground(.hidden)
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 480)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                onMicrophoneTapped()
            } label: {
                Label(
                    isRecording
                    ? "Stop"
                    : "Dictate",
                    systemImage:
                        isRecording
                        ? "stop.circle.fill"
                        : "mic.fill"
                )
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isRecording
                    ? NorthstarChatStyle.listening
                    : Color.white.opacity(0.16)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                )
            }

            Button {
                if isRecording {
                    onMicrophoneTapped()
                }

                onSave()
                dismiss()
            } label: {
                Label(
                    "Save PDF",
                    systemImage: "doc.badge.plus"
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
                .padding(.vertical, 14)
                .background(
                    Color(
                        red: 0.84,
                        green: 0.70,
                        blue: 0.36
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                )
            }
            .disabled(
                documentText
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
            )
            .opacity(
                documentText
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
                ? 0.45
                : 1
            )
        }
    }
}

#Preview {
    LivePDFDraftView(
        documentText: .constant(
            """
            Hi Mom.

            I hope you are having a good day.
            """
        ),
        isRecording: true,
        onMicrophoneTapped: {},
        onSave: {}
    )
}
