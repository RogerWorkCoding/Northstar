import SwiftUI
import AuthenticationServices

// ✦ First-run welcome: three short pages on the night sky, shown once.
// 1. What Northstar is. 2. What you can ask. 3. Your memory is yours (+ optional Sign in with Apple).
// Big text, one idea per page, always skippable. Settings → About can show it again later.

struct WelcomeView: View {
    var onDone: () -> Void

    @State private var page = 0
    @State private var account = AppleAccount.shared
    @State private var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
                HStack {
                    Spacer()
                    // Always takes its space (hidden on the last page) so the star never jumps.
                    Button("Skip") { onDone() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(minWidth: 44, minHeight: 44)
                        .opacity(page < 2 ? 1 : 0)
                        .disabled(page >= 2)
                        .accessibilityHidden(page >= 2)
                }
                .padding(.horizontal, 20)

                NorthstarVisionStarMark(size: 44)
                    .padding(.top, 24)
                    .accessibilityHidden(true)

                TabView(selection: $page) {
                    pageView(
                        title: "Find your direction",
                        lines: [
                            "Northstar helps you decide what matters,",
                            "then take the next small step.",
                            "Your direction is always yours."
                        ]
                    ).tag(0)

                    pageView(
                        title: "Talk or type",
                        lines: [
                            "Plan a project. Find a place nearby.",
                            "Sketch a design. Make a short video.",
                            "Simple questions get simple answers."
                        ]
                    ).tag(1)

                    memoryPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                Button {
                    if page < 2 {
                        withAnimation(reduceMotion ? nil : .easeInOut) { page += 1 }
                    } else {
                        onDone()
                    }
                } label: {
                    Text(page < 2 ? "Continue" : "Start")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.05, green: 0.09, blue: 0.21))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Capsule().fill(Color(red: 0.91, green: 0.93, blue: 1.0)))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: 480)
            }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The sky sits BEHIND the layout, so the picture never changes the layout's size.
        .background {
            ZStack {
                NorthstarVisionLandscapeBackground()
                // A soft veil so the words always read clearly over the sky.
                LinearGradient(colors: [Color.black.opacity(0.15), Color.black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
        // The welcome always sits on the night sky.
        .environment(\.colorScheme, .dark)
    }

    private func pageView(title: String, lines: [String]) -> some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.system(size: 32, weight: .light))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 8) {
                ForEach(lines, id: \.self) { Text($0) }
            }
            .font(.system(size: 19))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.88))
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
        }
        .padding(.top, 40)
        .padding(.horizontal, 28)
        .frame(maxWidth: 520)
    }

    private var memoryPage: some View {
        VStack(spacing: 18) {
            Text("Your memory is yours")
                .font(.system(size: 32, weight: .light))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 8) {
                Text("Northstar remembers only what you tell it or confirm.")
                Text("See, change or delete it any time in Settings.")
            }
            .font(.system(size: 19))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.88))
            .accessibilityElement(children: .combine)

            if account.isSignedInWithApple {
                Label("Signed in with Apple", systemImage: "checkmark.circle.fill")
                    .font(.body.weight(.semibold))
                    .padding(.top, 8)
            } else {
                VStack(spacing: 8) {
                    SignInWithAppleButton(.signIn) { request in
                        account.prepare(request)
                    } onCompletion: { result in
                        Task {
                            do {
                                try await account.finish(result)
                                message = account.cameBack
                                    ? "Welcome back. Your memory and chats are here again."
                                    : "Signed in. Your memory is safe if you change phones."
                            } catch {
                                if (error as? ASAuthorizationError)?.code == .canceled { return }
                                message = "Couldn't sign in. You can try later in Settings."
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .frame(maxWidth: 360)

                    Text("Optional. Creates your free account, no password.\nKeeps your memory safe if you change phones.")
                        .multilineTextAlignment(.center)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.top, 8)
            }

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 40)
        .padding(.horizontal, 28)
        .frame(maxWidth: 520)
    }
}

#Preview {
    WelcomeView(onDone: {})
}
