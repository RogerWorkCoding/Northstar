import SwiftUI

struct StarMenuView: View {

    @Binding var isPresented: Bool

    var onNewChat: () -> Void = {}
    var onCamera: () -> Void = {}
    var onPhotoLibrary: () -> Void = {}
    var onProjects: () -> Void = {}
    var onDiscovery: () -> Void = {}
    var onLearning: () -> Void = {}
    var onVoices: () -> Void = {}
    var onMemory: () -> Void = {}
    var onDocuments: () -> Void = {}
    var onHistory: () -> Void = {}
    var onSettings: () -> Void = {}
    var onAbout: () -> Void = {}
    var onFeedback: () -> Void = {}

    var body: some View {
        ZStack(alignment: .leading) {

            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    closeMenu()
                }

            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                menuHeader

                Divider()
                    .overlay(
                        .white.opacity(0.15)
                    )
                    .padding(.vertical, 14)

                menuButton(
                    title: "New Chat",
                    systemImage: "square.and.pencil",
                    action: onNewChat
                )

                menuButton(
                    title: "Camera",
                    systemImage: "camera",
                    action: onCamera
                )

                menuButton(
                    title: "Photo Library",
                    systemImage: "photo.on.rectangle",
                    action: onPhotoLibrary
                )

                sectionDivider

                menuButton(
                    title: "Projects",
                    systemImage: "folder",
                    action: onProjects
                )

                menuButton(
                    title: "Videos",
                    systemImage: "play.rectangle.on.rectangle",
                    action: onLearning
                )

                menuButton(
                    title: "Voices",
                    systemImage: "waveform",
                    action: onVoices
                )

                sectionDivider

                menuButton(
                    title: "Search Memory",
                    systemImage: "brain.head.profile",
                    action: onMemory
                )

                menuButton(
                    title: "Documents",
                    systemImage: "doc",
                    action: onDocuments
                )

                sectionDivider

                menuButton(
                    title: "Settings",
                    systemImage: "gearshape",
                    action: onSettings
                )

                menuButton(
                    title: "About Northstar",
                    systemImage: "info.circle",
                    action: onAbout
                )

                // Testers: feedback is one tap away, never hidden in Settings.
                menuButton(
                    title: "Send Feedback",
                    systemImage: "bubble.left.and.text.bubble.right",
                    action: onFeedback
                )

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .frame(width: 240)
            .frame(maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(
                        .white.opacity(0.12)
                    )
                    .frame(width: 1)
            }
        }
    }

    private var menuHeader: some View {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Image(systemName: "sparkle")
                    .font(
                        .system(
                            size: 24,
                            weight: .ultraLight
                        )
                    )
                    .foregroundStyle(.white)

                Text("Northstar")
                    .font(
                        .system(
                            size: 24,
                            weight: .light
                        )
                    )
                    .tracking(2)
                    .foregroundStyle(.white)
            }

            Spacer()
        }
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(
                .white.opacity(0.12)
            )
            .padding(.vertical, 10)
    }

    private func menuButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {

        Button {
            action()
            closeMenu()
        } label: {

            HStack(spacing: 14) {

                Image(systemName: systemImage)
                    .font(
                        .system(
                            size: 17,
                            weight: .light
                        )
                    )
                    .frame(width: 24)

                Text(title)
                    .font(
                        .system(
                            size: 17,
                            weight: .regular
                        )
                    )

                Spacer()
            }
            .foregroundStyle(
                .white.opacity(0.92)
            )
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func closeMenu() {
        withAnimation(
            .easeInOut(duration: 0.25)
        ) {
            isPresented = false
        }
    }
}

#Preview {
    StarMenuView(
        isPresented: .constant(true)
    )
    .background(
        Color(
            red: 0.08,
            green: 0.12,
            blue: 0.25
        )
    )
}
