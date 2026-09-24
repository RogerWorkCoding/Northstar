import SwiftUI

struct ContentView: View {
    @State private var promptText: String = ""

    var body: some View {
        ZStack {
            // 1. Atmosphere: Slate Blue Background
            Color(red: 0.08, green: 0.12, blue: 0.20)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 2. Focal Point: Glowing North Star using native SF Symbols
                Image(systemName: "sparkle")
                    .font(.system(size: 70, weight: .ultraLight))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.9), radius: 15, x: 0, y: 0)
                    .shadow(color: .white.opacity(0.4), radius: 30, x: 0, y: 0)
                    .padding(.bottom, 30)

                // 3. Identity
                Text("Northstar")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(.white)
                    .tracking(3)
                    .padding(.bottom, 16)

                // Manifesto
                VStack(spacing: 8) {
                    Text("ONE CLEAR DESTINATION.")
                    Text("AN INTELLIGENT PATH FORWARD.")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .tracking(2)

                Spacer()

                // 4. Entry Point: Glass-morphic Text Field
                HStack {
                    Button(action: {
                        // Camera trigger will go here
                    }) {
                        Image(systemName: "camera")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    TextField("", text: $promptText)
                        .placeholder(when: promptText.isEmpty) {
                            Text("Where would you like to go?")
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)

                    Button(action: {
                        // Microphone trigger will go here
                    }) {
                        Image(systemName: "mic")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                // Native iOS 15+ Glass-morphism
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .cornerRadius(25)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }
}

// Helper extension to keep the placeholder text cleanly styled
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
